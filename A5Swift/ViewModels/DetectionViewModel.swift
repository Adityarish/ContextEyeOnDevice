import CoreVideo
import Foundation
import ImageIO

@MainActor
final class DetectionViewModel: ObservableObject {
    @Published private(set) var detections: [Detection] = []
    @Published private(set) var imageSize: CGSize = .zero
    @Published var errorMessage: String?
    @Published var isSpeechEnabled = false
    @Published private(set) var isSessionRunning = false

    // ── Performance HUD ────────────────────────────────────────────────────────
    /// Last inference latency in milliseconds
    @Published private(set) var inferenceMs: Double = 0
    /// Smoothed frames-per-second
    @Published private(set) var fps: Double = 0

    let model: ModelRegistryItem
    let cameraService = CameraService()

    private let detector: ObjectDetectionService
    private let depthEstimator: DepthEstimationService
    private let speechService = SpeechService()
    private var hasStarted = false

    // Rolling FPS calculation (last 10 frame timestamps)
    private var frameTimes: [Double] = []
    private let maxFrameSamples = 10

    init(model: ModelRegistryItem, storageService: ModelStorageService) {
        self.model = model
        detector = ObjectDetectionService(storageService: storageService)
        depthEstimator = DepthEstimationService(storageService: storageService)
    }

    func start() async {
        guard !hasStarted else { return }

        hasStarted = true
        errorMessage = nil

        do {
            try detector.loadModel(named: model.name)
            cameraService.onFrame = { [weak self] pixelBuffer, orientation, frameSize in
                self?.handleFrame(pixelBuffer, orientation: orientation, imageSize: frameSize)
            }
            try await cameraService.start()
            isSessionRunning = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        hasStarted = false
        isSessionRunning = false
        detections = []
        inferenceMs = 0
        fps = 0
        frameTimes = []
        cameraService.stop()
    }

    private func handleFrame(
        _ pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        imageSize: CGSize
    ) {
        let start = Date()

        // 1. Fire off depth estimation asynchronously (it will cache internally every N frames)
        depthEstimator.processFrame(pixelBuffer, orientation: orientation)

        // 2. Fire YOLO asynchronously
        detector.processFrame(pixelBuffer, orientation: orientation, imageSize: imageSize) { [weak self] result in
            guard let self else { return }

            let elapsed = Date().timeIntervalSince(start) * 1000 // ms

            DispatchQueue.main.async {
                self.imageSize = imageSize
                self.inferenceMs = elapsed

                // Rolling FPS
                let now = Date().timeIntervalSinceReferenceDate
                self.frameTimes.append(now)
                if self.frameTimes.count > self.maxFrameSamples {
                    self.frameTimes.removeFirst()
                }
                if self.frameTimes.count >= 2 {
                    let span = self.frameTimes.last! - self.frameTimes.first!
                    self.fps = span > 0 ? Double(self.frameTimes.count - 1) / span : 0
                }

                switch result {
                case .success(let rawDetections):
                    // Limit to top 6 detections to avoid UI clutter and lag in busy scenes
                    let topDetections = Array(rawDetections.prefix(6))
                    
                    // Tag each detection with its distance based on the latest depth map
                    self.detections = topDetections.map { detection in
                        var d = detection
                        d.distance = self.depthEstimator.estimateDistance(for: d.boundingBox)
                        return d
                    }
                    if self.isSpeechEnabled {
                        self.speechService.speak(self.detections)
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
