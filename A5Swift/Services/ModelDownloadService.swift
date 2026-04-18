import Foundation

final class ModelDownloadService {
    private let storageService: ModelStorageService
    private let urlSession: URLSession

    init(storageService: ModelStorageService, urlSession: URLSession = .shared) {
        self.storageService = storageService
        self.urlSession = urlSession
    }

    func downloadModel(_ model: ModelRegistryItem) async throws {
        guard let remoteURL = URL(string: model.url) else {
            throw AppError.invalidModelURL(model.name)
        }

        if remoteURL.scheme == "bundle" {
            return
        }

        let (temporaryURL, response) = try await urlSession.download(from: remoteURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppError.failedToDownloadModel(model.name)
        }

        try storageService.persistDownloadedModel(from: temporaryURL, modelName: model.name)
    }
}
