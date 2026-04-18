import CoreML
import Foundation

final class ModelStorageService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - URL Helpers

    func rawModelURL(for modelName: String) -> URL {
        documentsDirectory
            .appendingPathComponent(sanitizedFileName(for: modelName))
            .appendingPathExtension("mlmodel")
    }

    func compiledModelURL(for modelName: String) -> URL {
        compiledModelsDirectory
            .appendingPathComponent(sanitizedFileName(for: modelName))
            .appendingPathExtension("mlmodelc")
    }

    // MARK: - Availability

    func isModelAvailable(named modelName: String) -> Bool {
        if bundledPackageURL(for: modelName) != nil {
            return true
        }
        return fileManager.fileExists(atPath: compiledModelURL(for: modelName).path)
    }

    // MARK: - Load

    /// Loads a compiled MLModel.
    /// For bundled .mlpackage models: compiles on first access, caches in Caches.
    /// For downloaded models: expects a pre-compiled .mlmodelc in CompiledModels.
    func loadModel(named modelName: String) throws -> MLModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        // ── Bundled .mlpackage path ───────────────────────────────────────────
        if let packageURL = bundledPackageURL(for: modelName) {
            let cachedURL = compiledModelURL(for: modelName)

            if !fileManager.fileExists(atPath: cachedURL.path) {
                // Compile the package and cache the result
                try createDirectoriesIfNeeded()
                let tempCompiledURL = try MLModel.compileModel(at: packageURL)
                // Move into our own cache so it survives warm relaunches
                if fileManager.fileExists(atPath: cachedURL.path) {
                    try fileManager.removeItem(at: cachedURL)
                }
                try fileManager.copyItem(at: tempCompiledURL, to: cachedURL)
            }

            return try MLModel(contentsOf: cachedURL, configuration: configuration)
        }

        // ── Downloaded model path ─────────────────────────────────────────────
        let compiledURL = compiledModelURL(for: modelName)

        if !fileManager.fileExists(atPath: compiledURL.path) {
            let rawURL = rawModelURL(for: modelName)

            guard fileManager.fileExists(atPath: rawURL.path) else {
                throw AppError.modelNotStoredLocally(modelName)
            }

            let tempCompiledURL = try MLModel.compileModel(at: rawURL)
            try createDirectoriesIfNeeded()
            try fileManager.copyItem(at: tempCompiledURL, to: compiledURL)
        }

        return try MLModel(contentsOf: compiledURL, configuration: configuration)
    }

    // MARK: - Persist Downloaded Model

    func persistDownloadedModel(from temporaryURL: URL, modelName: String) throws {
        try createDirectoriesIfNeeded()

        let rawURL = rawModelURL(for: modelName)
        let compiledURL = compiledModelURL(for: modelName)

        if fileManager.fileExists(atPath: rawURL.path) {
            try fileManager.removeItem(at: rawURL)
        }

        try fileManager.moveItem(at: temporaryURL, to: rawURL)

        let compiledTemporaryURL = try MLModel.compileModel(at: rawURL)

        if fileManager.fileExists(atPath: compiledURL.path) {
            try fileManager.removeItem(at: compiledURL)
        }

        try fileManager.copyItem(at: compiledTemporaryURL, to: compiledURL)
    }

    // MARK: - Delete

    func deleteModel(named modelName: String) throws {
        // Don't delete bundled models
        guard bundledPackageURL(for: modelName) == nil else { return }

        let rawURL = rawModelURL(for: modelName)
        let compiledURL = compiledModelURL(for: modelName)

        if fileManager.fileExists(atPath: rawURL.path) {
            try fileManager.removeItem(at: rawURL)
        }

        if fileManager.fileExists(atPath: compiledURL.path) {
            try fileManager.removeItem(at: compiledURL)
        }
    }

    // MARK: - Private Helpers

    /// Resolves the bundled .mlpackage URL for a given model name.
    /// Maps the display name used in model_registry.json to the resource name
    /// embedded in the app bundle.
    private func bundledPackageURL(for modelName: String) -> URL? {
        // YOLOv9-T  →  yolov9t_coreml.mlpackage
        if modelName.contains("YOLOv9-T") {
            return Bundle.main.url(forResource: "yolov9t_coreml", withExtension: "mlpackage")
        }
        // YOLO11-S  →  yolo11s_coreml.mlpackage
        if modelName.contains("YOLO11-S") {
            return Bundle.main.url(forResource: "yolo11s_coreml", withExtension: "mlpackage")
        }
        // Depth  →  depth_anything_v2_small.mlpackage
        if modelName == "depth_anything_v2_small" {
            return Bundle.main.url(forResource: "depth_anything_v2_small", withExtension: "mlpackage")
        }
        // Generic fallback using sanitized name (handles any future bundled models)
        let sanitized = sanitizedFileName(for: modelName)
        return Bundle.main.url(forResource: sanitized, withExtension: "mlpackage")
            ?? Bundle.main.url(forResource: sanitized, withExtension: "mlmodelc")
    }

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Compiled models are cached in Library/Caches so the OS can reclaim
    /// space if needed — the app will simply recompile on the next launch.
    private var compiledModelsDirectory: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("CompiledModels", isDirectory: true)
    }

    private func createDirectoriesIfNeeded() throws {
        try fileManager.createDirectory(
            at: compiledModelsDirectory,
            withIntermediateDirectories: true
        )
    }

    private func sanitizedFileName(for name: String) -> String {
        let cleanedName = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return cleanedName.isEmpty ? "model" : cleanedName
    }
}
