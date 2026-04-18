import Foundation

struct ModelRegistryItem: Codable, Identifiable, Hashable {
    let name: String
    let url: String
    let size: String
    let classes: Int

    var id: String { name }
}

struct ModelListEntry: Identifiable, Hashable {
    let registry: ModelRegistryItem
    var isDownloaded: Bool
    var isDownloading: Bool

    var id: String { registry.id }
}
