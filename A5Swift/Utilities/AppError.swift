import Foundation

enum AppError: LocalizedError {
    case registryNotFound
    case failedToLoadRegistry
    case invalidModelURL(String)
    case failedToDownloadModel(String)
    case failedToLoadModel(String)
    case modelNotStoredLocally(String)
    case incompatibleModelOutput
    case cameraPermissionDenied
    case cameraConfigurationFailed
    case noBackCameraAvailable

    var errorDescription: String? {
        switch self {
        case .registryNotFound:
            return "The bundled model registry could not be found."
        case .failedToLoadRegistry:
            return "The remote model registry could not be loaded."
        case .invalidModelURL(let modelName):
            return "The download URL for \(modelName) is invalid."
        case .failedToDownloadModel(let modelName):
            return "Downloading \(modelName) failed."
        case .failedToLoadModel(let reason):
            return "The model could not be loaded. \(reason)"
        case .modelNotStoredLocally(let modelName):
            return "\(modelName) is not stored on this device yet."
        case .incompatibleModelOutput:
            return "This Core ML model does not expose Vision object detections. Convert the YOLO model to a Vision-compatible object detector or add custom tensor decoding."
        case .cameraPermissionDenied:
            return "Camera access is required for real-time detection. Enable it in Settings."
        case .cameraConfigurationFailed:
            return "The camera session could not be configured."
        case .noBackCameraAvailable:
            return "No back camera is available on this device."
        }
    }
}
