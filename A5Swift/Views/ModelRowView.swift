import SwiftUI

struct ModelRowView: View {
    let model: ModelListEntry
    let onDownload: () -> Void
    let onRun: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.registry.name)
                        .font(.title3.weight(.semibold))

                    Text("\(model.registry.size) • \(model.registry.classes) classes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.14))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                if model.isDownloaded {
                    Button("Run", action: onRun)
                        .buttonStyle(.borderedProminent)

                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(.bordered)
                } else {
                    Button(action: onDownload) {
                        HStack(spacing: 8) {
                            if model.isDownloading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }

                            Text(model.isDownloading ? "Downloading..." : "Download")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isDownloading)
                }
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statusText: String {
        if model.isDownloading { return "Downloading" }
        return model.isDownloaded ? "Ready Offline" : "Remote"
    }

    private var statusColor: Color {
        if model.isDownloading { return .orange }
        return model.isDownloaded ? .green : .blue
    }
}
