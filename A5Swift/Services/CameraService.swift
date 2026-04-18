import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ImageIO

final class CameraService: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var isAuthorized = false

    let session = AVCaptureSession()
    var onFrame: ((CVPixelBuffer, CGImagePropertyOrientation, CGSize) -> Void)?

    private let sessionQueue = DispatchQueue(label: "CameraService.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "CameraService.frames")

    private var isConfigured = false

    func start() async throws {
        let accessGranted = await requestAccessIfNeeded()
        guard accessGranted else {
            throw AppError.cameraPermissionDenied
        }

        if !isConfigured {
            try await configureSession()
        }

        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run { isAuthorized = true }
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { accessGranted in
                    continuation.resume(returning: accessGranted)
                }
            }
            await MainActor.run { isAuthorized = granted }
            return granted
        default:
            await MainActor.run { isAuthorized = false }
            return false
        }
    }

    private func configureSession() async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .high

                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw AppError.noBackCameraAvailable
                    }

                    let input = try AVCaptureDeviceInput(device: camera)
                    guard self.session.canAddInput(input) else {
                        throw AppError.cameraConfigurationFailed
                    }
                    self.session.addInput(input)

                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                    ]
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.frameQueue)

                    guard self.session.canAddOutput(self.videoOutput) else {
                        throw AppError.cameraConfigurationFailed
                    }
                    self.session.addOutput(self.videoOutput)

                    if let connection = self.videoOutput.connection(with: .video),
                       connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }

                    self.session.commitConfiguration()
                    self.isConfigured = true
                    continuation.resume(returning: ())
                } catch {
                    self.session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // The AVCaptureConnection is already rotated 90°, so the pixel buffer
        // arrives as a portrait frame (tall, not wide). Vision must be told the
        // image is already upright (.up), otherwise it applies a second rotation
        // and the bounding boxes end up in completely the wrong position.
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let bufferWidth  = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)

        // After the 90° hardware rotation the logical portrait size is (width=H, height=W)
        let frameSize = CGSize(width: bufferHeight, height: bufferWidth)

        onFrame?(pixelBuffer, .up, frameSize)
    }
}
