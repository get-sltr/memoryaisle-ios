@preconcurrency import AVFoundation
import Speech
import SwiftUI

@Observable
final class VoiceManager: NSObject, @unchecked Sendable {
    /// Shared singleton. Creating a VoiceManager instantiates AVAudioEngine
    /// and AVSpeechSynthesizer, both of which contact mediaserverd over IPC
    /// and can block the main thread for several seconds. Re-creating one on
    /// every Mira tab entry blew past the 3-second mediaserverd budget and
    /// triggered the iOS watchdog SIGKILL. One shared instance fixes that.
    static let shared = VoiceManager()

    var isListening = false
    var isSpeaking = false
    var transcribedText = ""
    var error: String?
    var autoListen = false
    /// Smoothed RMS amplitude of the live microphone input, scaled 0...1.
    /// Computed in the same audio tap that feeds speech recognition so the
    /// editorial Mira bars can react without spinning up a second engine.
    /// Always 0 when not listening.
    var audioLevel: CGFloat = 0

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

    // The audio-permission call needs MainActor (AVAudioApplication
    // .requestRecordPermission asserts main on iOS 17). The speech-permission
    // call must NOT be MainActor: SFSpeechRecognizer.requestAuthorization
    // delivers its callback from the TCCD worker thread, and a MainActor
    // continuation captured in that callback trips dispatch_assert_queue_fail
    // in the Swift concurrency thunk before the body even runs. Splitting
    // them keeps each on the right executor.
    func requestPermissions() async -> Bool {
        let speechStatus = await Self.requestSpeechAuthorization()
        let audioStatus = await Self.requestAudioRecordPermission()
        return speechStatus && audioStatus
    }

    private static func requestSpeechAuthorization() async -> Bool {
        // Wrapped in Task.detached so the continuation is owned by an
        // unstructured task with no inherited actor isolation. Without
        // this, the SFSpeechRecognizer callback (delivered from TCCD's
        // XPC worker) hits an executor-mismatch assertion in the Swift
        // concurrency thunk and crashes before the closure body runs.
        await Task.detached(priority: .userInitiated) {
            await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
        }.value
    }

    @MainActor
    private static func requestAudioRecordPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Audio Session
    //
    // AVAudioSession.setCategory / setActive call into mediaserverd over IPC
    // and can block for hundreds of milliseconds. When invoked on the main
    // thread from the speak() path, this produces a "Result accumulator
    // timeout: 3.000000 exceeded" log followed by a _dispatch_assert_queue_fail
    // crash on a libdispatch concurrent worker thread. The fix is to run
    // session configuration on a detached task before touching AVAudioPlayer.
    //
    // The listen path (startListening) keeps the synchronous call because
    // SFSpeechRecognizer / AVAudioEngine setup must happen on the main
    // thread anyway and is not part of the result-accumulator chain.

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

    /// Off-main wrapper around `configureAudioSession`. Used by the speak path
    /// so the blocking IPC call to mediaserverd does not run on the main
    /// thread and trip the result-accumulator timeout.
    nonisolated private func configureAudioSessionAsync(forRecording: Bool) async -> Bool {
        await Task.detached(priority: .userInitiated) { [weak self] in
            self?.configureAudioSession(forRecording: forRecording) ?? false
        }.value
    }

    nonisolated private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Off-main wrapper around `deactivateAudioSession`. Use from any
    /// MainActor context (e.g. view onDisappear) to release the audio
    /// session without blocking the UI thread.
    nonisolated func deactivateAudioSessionAsync() async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            self?.deactivateAudioSession()
        }.value
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

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // Audio thread - append is thread-safe on the request object.
            request.append(buffer)

            // Compute RMS so the editorial Mira bars can visualize the live
            // mic level. Cheap (one pass over the buffer); shipping values
            // back to main on every tap is fine at 1024-frame buffers.
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }

            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            // Empirical scale - typical speech RMS is ~0.05-0.12; multiplying
            // by 12 lifts it into the 0.6-1.5 range, then we clamp.
            let level = max(0, min(1, rms * 12))

            Task { @MainActor [weak self] in
                guard let self else { return }
                // Low-pass smoothing - bars feel calmer than raw RMS, which
                // would jitter on every tap.
                self.audioLevel = self.audioLevel * 0.7 + CGFloat(level) * 0.3
            }
        }
        hasInstalledTap = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, err in
            // Recognition callback can arrive on any thread - hop back.
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
        audioLevel = 0
    }

    // MARK: - Speak (Text to Speech)

    /// Speaks text using Polly Generative (remote) with Apple TTS fallback.
    /// Tries the cloud voice first for natural tone; if the network call
    /// fails for any reason, falls back to the on-device synthesizer.
    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        // Stop anything already playing
        Task { @MainActor in
            self.stopSpeaking()
        }

        Task {
            // Configure session OFF main first. If it fails, we cannot play
            // remote audio safely either, so fall straight to local TTS.
            let sessionOK = await configureAudioSessionAsync(forRecording: false)
            guard sessionOK else {
                await speakLocally(text)
                return
            }

            do {
                let audioData = try await ttsClient.synthesize(text: text)
                await MainActor.run {
                    self.playRemoteAudio(audioData)
                }
            } catch {
                // Network or Polly failed - fall back to on-device TTS.
                // Session is already configured for playback above, so
                // speakLocally only has to schedule the utterance.
                await speakLocally(text)
            }
        }
    }

    /// Plays an MP3 audio data blob returned by the Polly Lambda.
    /// Caller is responsible for having configured the audio session for
    /// playback before invoking this method.
    @MainActor
    private func playRemoteAudio(_ data: Data) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.volume = 1.0
            player.prepareToPlay()
            audioPlayer = player
            isSpeaking = true
            player.play()
        } catch {
            // Can't decode - clear state and let the UI reflect the failure.
            audioPlayer = nil
            isSpeaking = false
        }
    }

    /// Fallback: Apple on-device TTS.
    /// Configures the playback audio session off-main if needed, then
    /// schedules the utterance on the main actor.
    private func speakLocally(_ text: String) async {
        // Best-effort session configuration off main. If it fails we still
        // attempt to speak; AVSpeechSynthesizer can sometimes proceed with
        // a default ambient session.
        _ = await configureAudioSessionAsync(forRecording: false)

        await MainActor.run {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = Self.bestAvailableVoice()
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.0
            utterance.pitchMultiplier = 1.08
            utterance.volume = 1.0
            utterance.preUtteranceDelay = 0.05
            utterance.postUtteranceDelay = 0.1

            self.isSpeaking = true
            self.synthesizer.speak(utterance)
        }
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

    @MainActor
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
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}

extension VoiceManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
            self?.audioPlayer = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
            self?.audioPlayer = nil
        }
    }
}
