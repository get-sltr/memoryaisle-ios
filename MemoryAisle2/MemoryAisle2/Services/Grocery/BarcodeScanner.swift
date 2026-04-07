@preconcurrency import AVFoundation
import SwiftUI
@preconcurrency import Vision

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onBarcodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerController {
        let controller = BarcodeScannerController()
        controller.onBarcodeDetected = onBarcodeDetected
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerController, context: Context) {}
}

final class BarcodeScannerController: UIViewController {
    var onBarcodeDetected: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.sltrdigital.barcode", qos: .userInitiated)
    private nonisolated(unsafe) var lastDetectedBarcode: String?
    private nonisolated(unsafe) var lastDetectionTime: Date = .distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        requestCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        processingQueue.async { [captureSession] in
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        processingQueue.async { [captureSession] in
            captureSession.stopRunning()
        }
    }

    // MARK: - Permission

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            // Show message that camera is needed
            DispatchQueue.main.async { [weak self] in
                self?.showPermissionDenied()
            }
        @unknown default:
            break
        }
    }

    private func showPermissionDenied() {
        let label = UILabel()
        label.text = "Camera access needed\nGo to Settings > MemoryAisle"
        label.textColor = .white.withAlphaComponent(0.4)
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        // Start immediately
        processingQueue.async { [captureSession] in
            captureSession.startRunning()
        }
    }
}

// MARK: - Barcode Detection

extension BarcodeScannerController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastDetectionTime) > 0.5 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard error == nil,
                  let results = request.results as? [VNBarcodeObservation],
                  let barcode = results.first,
                  let payload = barcode.payloadStringValue else { return }

            guard payload != self?.lastDetectedBarcode else { return }

            self?.lastDetectedBarcode = payload
            self?.lastDetectionTime = Date()

            DispatchQueue.main.async {
                self?.onBarcodeDetected?(payload)
            }
        }

        request.symbologies = [.ean8, .ean13, .upce, .code128, .code39, .qr, .dataMatrix]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
