import SwiftUI

struct DetectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DetectionViewModel
    @State private var showSpeechToggle = false

    init(model: ModelRegistryItem, storageService: ModelStorageService) {
        _viewModel = StateObject(wrappedValue: DetectionViewModel(model: model, storageService: storageService))
    }

    var body: some View {
        ZStack {
            // ── Camera feed ───────────────────────────────────────────────────
            CameraPreviewView(session: viewModel.cameraService.session)
                .ignoresSafeArea()

            // ── Bounding boxes ────────────────────────────────────────────────
            DetectionOverlayView(
                detections: viewModel.detections,
                imageSize: viewModel.imageSize
            )
            .ignoresSafeArea()

            // ── All HUD elements on top ───────────────────────────────────────
            VStack(spacing: 0) {
                // Top row: back button  ····  performance stats
                HStack(alignment: .top) {
                    backButton
                    Spacer()
                    performanceHUD
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                // Bottom row: count + model name  ····  action rail
                HStack(alignment: .bottom) {
                    statsFooter
                    Spacer()
                    actionRail
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .background(.black)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .alert("Detection Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Top-left back button

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.50), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - Top-right: inference time + FPS

    private var performanceHUD: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(format: "%.0f ms", viewModel.inferenceMs))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(.white)

            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(format: "%.1f fps", viewModel.fps))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Bottom-left: object count + model name

    private var statsFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Total Count : \(viewModel.detections.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 6) {
                Image(systemName: "line.diagonal.arrow")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Text(shortModelName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Strips the "(Bundled)" suffix for display
    private var shortModelName: String {
        viewModel.model.name
            .replacingOccurrences(of: " (Bundled)", with: "")
            .replacingOccurrences(of: "(Bundled)", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Bottom-right: vertical action rail

    private var actionRail: some View {
        VStack(spacing: 12) {
            // Scan / detection icon
            actionButton(systemImage: "viewfinder.rectangular", action: {})

            // Speech toggle
            actionButton(
                systemImage: viewModel.isSpeechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                tint: viewModel.isSpeechEnabled ? .green : .white,
                action: { viewModel.isSpeechEnabled.toggle() }
            )
        }
    }

    private func actionButton(
        systemImage: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(.black.opacity(0.50), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
        }
    }

    // MARK: - Error binding

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
