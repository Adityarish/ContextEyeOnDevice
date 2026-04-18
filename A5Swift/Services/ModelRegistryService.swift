import Foundation

final class ModelRegistryService {
    private let registryURL: URL?
    private let urlSession: URLSession

    init(registryURL: URL?, urlSession: URLSession = .shared) {
        self.registryURL = registryURL
        self.urlSession = urlSession
    }

    func fetchModels() async throws -> [ModelRegistryItem] {
        if let registryURL {
            do {
                let (data, response) = try await urlSession.data(from: registryURL)

                if let httpResponse = response as? HTTPURLResponse,
                   !(200..<300).contains(httpResponse.statusCode) {
                    throw AppError.failedToLoadRegistry
                }

                return try decodeRegistry(from: data)
            } catch {
                return try loadBundledRegistry()
            }
        }

        return try loadBundledRegistry()
    }

    private func decodeRegistry(from data: Data) throws -> [ModelRegistryItem] {
        try JSONDecoder().decode([ModelRegistryItem].self, from: data)
    }

    private func loadBundledRegistry() throws -> [ModelRegistryItem] {
        guard let bundledURL = Bundle.main.url(forResource: "model_registry", withExtension: "json") else {
            throw AppError.registryNotFound
        }

        let data = try Data(contentsOf: bundledURL)
        return try decodeRegistry(from: data)
    }
}
