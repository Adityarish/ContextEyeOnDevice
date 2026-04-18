import Foundation

struct AppEnvironment {
    let modelRegistryService: ModelRegistryService
    let modelStorageService: ModelStorageService
    let modelDownloadService: ModelDownloadService

    static let live: AppEnvironment = {
        let storageService = ModelStorageService()
        let registryService = ModelRegistryService(
            registryURL: URL(string: "https://your-server.com/models/registry.json")
        )
        let downloadService = ModelDownloadService(storageService: storageService)

        return AppEnvironment(
            modelRegistryService: registryService,
            modelStorageService: storageService,
            modelDownloadService: downloadService
        )
    }()
}
