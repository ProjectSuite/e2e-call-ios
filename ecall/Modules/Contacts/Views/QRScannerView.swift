import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var scannedKey: String
    var onDismiss: (() -> Void)?
    var onScanAgain: (() -> Void)? // Callback when scan again is tapped

    // State to track if QR has been scanned
    @State private var hasScanned: Bool = false
    @State private var scannedResult: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.scannerDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: QRScannerView

        init(_ parent: QRScannerView) {
            self.parent = parent
        }

        func didScan(result: String) {
            // Set state to show scan again button
            parent.hasScanned = true
            parent.scannedResult = result

            parent.scannedKey = result
            parent.onDismiss?()
        }

        func didTapScanAgain() {
            parent.onScanAgain?()
        }
    }
}

// MARK: - ScannerViewController
protocol ScannerViewControllerDelegate: AnyObject {
    func didScan(result: String)
    func didTapScanAgain()
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var scannerDelegate: ScannerViewControllerDelegate?

    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "qr.session.queue", qos: .userInitiated)

    // UI Elements
    private var scanAgainButton: UIButton?
    private var resultLabel: UILabel?
    private var hasScanned: Bool = false
    private var scannedResult: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            debugLog("No video device found.")
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            debugLog("Cannot create video input.")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            debugLog("Cannot add video input to session.")
            return
        }

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            debugLog("Cannot add metadata output.")
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        if let conn = previewLayer.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        updateRectOfInterest()
        // Start the session on a background queue to avoid UI stalls
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }

        setupScanAgainUI()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        if let conn = previewLayer?.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        updateRectOfInterest()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateRectOfInterest()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            if let conn = self.previewLayer?.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
            self.previewLayer?.frame = self.view.layer.bounds
        }, completion: { _ in
            self.updateRectOfInterest()
        })
    }

    private func updateRectOfInterest() {
        guard let previewLayer = previewLayer else { return }
        let layerRect = view.layer.bounds // visible 300pt region
        if layerRect.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.updateRectOfInterest() }
            return
        }
        let roi = previewLayer.metadataOutputRectConverted(fromLayerRect: layerRect)
        if roi.width <= 0 || roi.height <= 0 {
            // Fallback: full frame if conversion fails
            metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        } else {
            metadataOutput.rectOfInterest = roi
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let stringValue = object.stringValue else { return }

        // Debug prints: print data then additional info
        debugLog("[QR] scanned string: \(stringValue)")

        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.showScanAgainUI(with: stringValue)
                self?.scannerDelegate?.didScan(result: stringValue)
            }
        }
    }

    private func showScanAgainUI(with result: String) {
        hasScanned = true
        scannedResult = result

        resultLabel?.text = "QR Code detected: \(String(result.prefix(20)))..."
        resultLabel?.isHidden = false

        scanAgainButton?.isHidden = false
    }

    private func setupScanAgainUI() {
        // Scan again button
        scanAgainButton = UIButton(type: .system)
        scanAgainButton?.setTitle(KeyLocalized.scan_again, for: .normal)
        scanAgainButton?.setTitleColor(.white, for: .normal)
        scanAgainButton?.backgroundColor = UIColor.systemBlue
        scanAgainButton?.layer.cornerRadius = 20
        scanAgainButton?.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        scanAgainButton?.addTarget(self, action: #selector(scanAgainTapped), for: .touchUpInside)
        scanAgainButton?.isHidden = true

        if let scanAgainButton = scanAgainButton {
            view.addSubview(scanAgainButton)
            scanAgainButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                scanAgainButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                scanAgainButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
                scanAgainButton.widthAnchor.constraint(equalToConstant: 120),
                scanAgainButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
    }

    @objc private func scanAgainTapped() {
        // Reset state
        hasScanned = false
        scannedResult = ""

        // Hide UI elements
        scanAgainButton?.isHidden = true

        scannerDelegate?.didTapScanAgain()

        // Restart scanning
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
}
