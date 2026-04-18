import SwiftUI

struct ModelListView: View {
    @StateObject private var viewModel: ModelListViewModel
    private let environment: AppEnvironment

    init(environment: AppEnvironment = .live) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ModelListViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.models.isEmpty {
                    ProgressView("Loading models...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.models.isEmpty {
                    ContentUnavailableView(
                        "No Models Found",
                        systemImage: "shippingbox",
                        description: Text("Point the registry URL at your server or update the bundled JSON registry.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(viewModel.models) { model in
                                ModelRowView(
                                    model: model,
                                    onDownload: { viewModel.downloadModel(model) },
                                    onRun: { viewModel.runModel(model) },
                                    onDelete: { viewModel.deleteModel(model) }
                                )
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                        } footer: {
                            Text("Downloaded models are stored in the app's Documents directory and compiled into .mlmodelc bundles for offline inference.")
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.08), Color.white, Color.green.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .navigationTitle("Offline YOLO")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadModels() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if viewModel.models.isEmpty {
                    await viewModel.loadModels()
                }
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $viewModel.selectedModel) { model in
                NavigationStack {
                    DetectionView(model: model, storageService: environment.modelStorageService)
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.dismissError()
                }
            }
        )
    }
}
