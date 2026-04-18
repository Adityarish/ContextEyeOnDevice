import Foundation

@MainActor
final class ModelListViewModel: ObservableObject {
    @Published private(set) var models: [ModelListEntry] = []
    @Published var selectedModel: ModelRegistryItem?
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let registryService: ModelRegistryService
    private let storageService: ModelStorageService
    private let downloadService: ModelDownloadService

    init(environment: AppEnvironment) {
        registryService = environment.modelRegistryService
        storageService = environment.modelStorageService
        downloadService = environment.modelDownloadService
    }

    func loadModels() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let registry = try await registryService.fetchModels()
            models = registry.map { item in
                ModelListEntry(
                    registry: item,
                    isDownloaded: storageService.isModelAvailable(named: item.name),
                    isDownloading: false
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadModel(_ entry: ModelListEntry) {
        guard let index = index(for: entry.id), !models[index].isDownloading else { return }

        models[index].isDownloading = true
        errorMessage = nil

        Task {
            do {
                try await downloadService.downloadModel(entry.registry)
                models[index].isDownloading = false
                models[index].isDownloaded = true
            } catch {
                models[index].isDownloading = false
                models[index].isDownloaded = storageService.isModelAvailable(named: entry.registry.name)
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteModel(_ entry: ModelListEntry) {
        do {
            try storageService.deleteModel(named: entry.registry.name)
            refreshLocalState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runModel(_ entry: ModelListEntry) {
        selectedModel = entry.registry
    }

    func dismissError() {
        errorMessage = nil
    }

    private func refreshLocalState() {
        models = models.map { entry in
            var updatedEntry = entry
            updatedEntry.isDownloaded = storageService.isModelAvailable(named: entry.registry.name)
            updatedEntry.isDownloading = false
            return updatedEntry
        }
    }

    private func index(for id: String) -> Int? {
        models.firstIndex(where: { $0.id == id })
    }
}
