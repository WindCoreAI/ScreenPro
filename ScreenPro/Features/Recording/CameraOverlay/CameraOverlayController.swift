import Foundation
import AVFoundation
import AppKit
import Combine

// MARK: - CameraOverlayController (T074)

/// Controller for managing the camera overlay during recording.
@MainActor
final class CameraOverlayController: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Current camera state.
    @Published private(set) var state: CameraState = .idle

    /// Current overlay configuration.
    @Published var config: OverlayConfig = .default

    // MARK: - Properties

    /// The AV capture session.
    private var captureSession: AVCaptureSession?

    /// The video preview layer.
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    /// The camera input.
    private var videoInput: AVCaptureDeviceInput?

    /// The video output for frame capture.
    private var videoOutput: AVCaptureVideoDataOutput?

    /// Queue for video processing.
    private let videoQueue = DispatchQueue(label: "com.screenpro.cameraoverlay", qos: .userInteractive)

    /// Current video frame for compositing.
    private(set) var currentFrame: CMSampleBuffer?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Starts the camera session.
    func start() async throws {
        guard !state.isRunning else { return }

        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                state = .failed(.permissionDenied)
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            state = .failed(.permissionDenied)
            throw CameraError.permissionDenied
        case .authorized:
            break
        @unknown default:
            break
        }

        // Create capture session
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        // Get camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
              ?? AVCaptureDevice.default(for: .video) else {
            state = .failed(.deviceNotFound)
            throw CameraError.deviceNotFound
        }

        // Create input
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            } else {
                throw CameraError.sessionConfigurationFailed
            }
        } catch {
            state = .failed(.sessionConfigurationFailed)
            throw CameraError.sessionConfigurationFailed
        }

        // Create video output for frame capture
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
        }

        // Create preview layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer

        captureSession = session

        // Start session on background thread
        videoQueue.async { [weak self] in
            session.startRunning()
            Task { @MainActor [weak self] in
                self?.state = .running(device: camera.localizedName)
            }
        }
    }

    /// Stops the camera session.
    func stop() {
        videoQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }

        captureSession = nil
        videoInput = nil
        videoOutput = nil
        previewLayer = nil
        currentFrame = nil
        state = .idle
    }

    /// Toggles the camera on/off.
    func toggle() async throws {
        if state.isRunning {
            stop()
        } else {
            try await start()
        }
    }

    /// Gets the current frame as a CGImage for compositing.
    func getCurrentFrame() -> CGImage? {
        guard let sampleBuffer = currentFrame,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return cgImage
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraOverlayController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Store the latest frame for compositing
        Task { @MainActor [weak self] in
            self?.currentFrame = sampleBuffer
        }
    }
}
