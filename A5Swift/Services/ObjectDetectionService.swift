import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision

final class ObjectDetectionService {
    private let storageService: ModelStorageService
    private let processingQueue = DispatchQueue(label: "ObjectDetectionService.processing")
    private let confidenceThreshold: Float

    private var visionModel: VNCoreMLModel?
    private var isProcessingFrame = false

    init(storageService: ModelStorageService, confidenceThreshold: Float = 0.45) {
        self.storageService = storageService
        self.confidenceThreshold = confidenceThreshold
    }

    func loadModel(named modelName: String) throws {
        let coreMLModel = try storageService.loadModel(named: modelName)
        visionModel = try VNCoreMLModel(for: coreMLModel)
    }

    func processFrame(
        _ pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        imageSize _: CGSize,
        completion: @escaping (Result<[Detection], Error>) -> Void
    ) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            guard let visionModel = self.visionModel else {
                completion(.failure(AppError.failedToLoadModel("Load a model before running inference.")))
                return
            }
            guard !self.isProcessingFrame else { return }

            self.isProcessingFrame = true
            defer { self.isProcessingFrame = false }

            var detections: [Detection] = []
            var incompatibleOutput = false
            var requestError: Error?

            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error {
                    requestError = error
                    return
                }

                if let observations = request.results as? [VNRecognizedObjectObservation] {
                    detections = observations
                        .compactMap { observation in
                            guard let label = observation.labels.first,
                                  label.confidence >= self.confidenceThreshold else {
                                return nil
                            }

                            return Detection(
                                label: label.identifier,
                                confidence: label.confidence,
                                boundingBox: observation.boundingBox
                            )
                        }
                        .sorted { $0.confidence > $1.confidence }
                } else if let results = request.results, !results.isEmpty {
                    incompatibleOutput = true
                }
            }

            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: orientation,
                options: [:]
            )

            do {
                try handler.perform([request])

                if let requestError {
                    completion(.failure(requestError))
                } else if incompatibleOutput {
                    completion(.failure(AppError.incompatibleModelOutput))
                } else {
                    completion(.success(detections))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}
