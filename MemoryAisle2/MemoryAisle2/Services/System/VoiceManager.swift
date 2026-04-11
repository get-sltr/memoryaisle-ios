@preconcurrency import AVFoundation
import Speech
import SwiftUI

@Observable
final class VoiceManager: NSObject, @unchecked Sendable {
    var isListening = false
    var isSpeaking = false
    var transcribedText = ""
    var error: String?
    var autoListen = false

    @ObservationIgnored nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    @ObservationIgnored nonisolated(unsafe) private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored nonisolated(unsafe) private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored nonisolated(unsafe) private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored nonisolated(unsafe) private var hasInstalledTap = false
    @ObservationIgnored private let ttsClient = MiraTTSClient()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        let audioStatus: Bool
        if #available(iOS 17.0, *) {
            audioStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            audioStatus = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }

        return speechStatus && audioStatus
    }

    // MARK: - Audio Session

    @discardableResult
    nonisolated private func configureAudioSession(forRecording: Bool) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            if forRecording {
                // STT mode - needs microphone input
                try session.setCategory(
                    .playAndRecord,
                    mode: .measurement,
                    options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
            } else {
                // TTS playback only - no microphone needed
                try session.setCategory(
                    .playback,
                    mode: .spokenAudio,
                    options: [.duckOthers]
                )
            }
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            return true
        } catch {
            return false
        }
    }

    /// Called when leaving a Mira session - deactivates audio session
    /// so it doesn't block subsequent audio calls.
    nonisolated private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Listen (Speech to Text)

    /// Starts listening for speech. @MainActor because AVAudioEngine and
    /// SFSpeechRecognizer both have internal queue assertions that will
    /// trap the app if this code runs off the main thread.
    @MainActor
    func startListening() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard !isListening else { return }
        guard speechRecognizer?.isAvailable == true else {
            error = "Speech recognition not available"
            return
        }

        transcribedText = ""
        error = nil

        teardownAudioEngine()

        guard configureAudioSession(forRecording: true) else {
            error = "Could not configure audio session"
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.channelCount > 0, recordingFormat.sampleRate > 0 else {
            error = "Microphone not available"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            // Audio thread — append is thread-safe on the request object.
            request.append(buffer)
        }
        hasInstalledTap = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, err in
            // Recognition callback can arrive on any thread — hop back.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.teardownAudioEngine()
                        self.isListening = false
                    }
                }
                if err != nil {
                    self.teardownAudioEngine()
                    self.isListening = false
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            teardownAudioEngine()
            isListening = false
            self.error = "Could not start audio engine"
        }
    }

    @MainActor
    func stopListening() {
        dispatchPrecondition(condition: .onQueue(.main))
        teardownAudioEngine()
        isListening = false
    }

    /// Must be called on the main actor. Tears down audio engine, tap,
    /// and recognition task. Safe to call multiple times.
    @MainActor
    private func teardownAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    // MARK: - Speak (Text to Speech)

    /// Speaks text using Polly Generative (remote) with Apple TTS fallback.
    /// Tries the cloud voice first for natural tone; if the network call
    /// fails for any reason, falls back to the on-device synthesizer.
    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        // Stop anything already playing
        stopSpeaking()

        Task {
            do {
                let audioData = try await ttsClient.synthesize(text: text)
                await MainActor.run {
                    self.playRemoteAudio(audioData)
                }
            } catch {
                // Network or Polly failed - fall back to on-device TTS
                await MainActor.run {
                    self.speakLocally(text)
                }
            }
        }
    }

    /// Plays an MP3 audio data blob returned by the Polly Lambda.
    private func playRemoteAudio(_ data: Data) {
        _ = configureAudioSession(forRecording: false)
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.volume = 1.0
            player.prepareToPlay()
            audioPlayer = player
            isSpeaking = true
            player.play()
        } catch {
            // Can't decode - fall back to Apple TTS with same text
            // (we don't have the text here, so just mark not speaking)
            audioPlayer = nil
            isSpeaking = false
        }
    }

    /// Fallback: Apple on-device TTS.
    private func speakLocally(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestAvailableVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.0
        utterance.pitchMultiplier = 1.08
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.1

        _ = configureAudioSession(forRecording: false)

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Picks the best-sounding installed English voice. Prefers, in order:
    /// 1. Siri voices (Nicky, Aaron) - highest natural quality, often pre-installed
    /// 2. Premium (neural) voices
    /// 3. Enhanced voices
    /// 4. Any default English voice with a feminine bias (for Mira's personality)
    private static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let englishVoices = allVoices.filter { $0.language.hasPrefix("en") }

        // Tier 1: Siri voices (identifiers contain "siri")
        if let siri = englishVoices.first(where: {
            $0.identifier.lowercased().contains("siri")
        }) {
            return siri
        }

        // Tier 2: Premium quality voices
        if let premium = englishVoices.first(where: {
            $0.quality == .premium
        }) {
            return premium
        }

        // Tier 3: Enhanced quality voices
        if let enhanced = englishVoices.first(where: {
            $0.quality == .enhanced
        }) {
            return enhanced
        }

        // Tier 4: Prefer en-US feminine-sounding default voices
        let preferredNames = ["Samantha", "Ava", "Allison", "Susan", "Zoe"]
        for name in preferredNames {
            if let match = englishVoices.first(where: {
                $0.name.contains(name) && $0.language == "en-US"
            }) {
                return match
            }
        }

        // Final fallback
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        isSpeaking = false
        autoListen = false
    }
}

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

extension VoiceManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.audioPlayer = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.audioPlayer = nil
        }
    }
}
