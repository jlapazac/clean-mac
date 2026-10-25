import CleanMacCore
import SwiftUI

struct AppsView: View {
    @Bindable var model: AppsViewModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    TextField("Buscar apps", text: $model.search)
                        .textFieldStyle(.roundedBorder)
                    Picker("Ordenar", selection: $model.sortOrder) {
                        ForEach(AppsViewModel.SortOrder.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Button("Recargar", systemImage: "arrow.clockwise", action: model.reload)
                        .labelStyle(.iconOnly)
                        .disabled(model.isLoading)
                }
                .padding(10)
                Divider()
                if model.isLoading {
                    ProgressView("Buscando aplicaciones…").frame(maxHeight: .infinity)
                } else {
                    List(model.visibleApps, selection: $model.selectedAppID) { app in
                        AppRow(app: app, isMeasuring: model.leftoversPending.contains(app.id))
                            .tag(app.id)
                    }
                }
                if !model.leftoversPending.isEmpty && !model.isLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Calculando restos de \(model.leftoversPending.count) apps…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(6)
                }
            }
            .frame(minWidth: 340, idealWidth: 400)

            Group {
                if let app = model.selectedApp {
                    AppDetailView(model: model, app: app)
                } else {
                    VStack(spacing: 12) {
                        if let result = model.lastResult { DeletionResultView(result: result) }
                        ContentUnavailableView("Selecciona una app",
                                               systemImage: "app.dashed",
                                               description: Text("Verás su tamaño real: el paquete más los datos que deja en tu Library."))
                    }
                    .padding()
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Aplicaciones")
        .onAppear(perform: model.loadIfNeeded)
        .sheet(item: Binding(
            get: { model.pendingDeletion.map(PendingBatch.init) },
            set: { if $0 == nil { model.pendingDeletion = nil } }
        )) { batch in
            ConfirmationSheet(
                title: "¿Desinstalar \(model.selectedApp?.name ?? "la app")?",
                items: batch.items,
                onConfirm: model.confirmDeletion,
                onCancel: { model.pendingDeletion = nil })
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let isMeasuring: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: SystemServices.icon(for: app.url))
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(app.name).lineLimit(1)
                    if app.isAppleApp {
                        Image(systemName: "applelogo").font(.caption).foregroundStyle(.tertiary)
                            .help("App de Apple: no se puede desinstalar")
                    }
                    if app.isRunning {
                        Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.green)
                            .help("En ejecución")
                    }
                }
                Text("App \(ByteFormatting.string(app.bundleSize)) · Restos \(isMeasuring ? "…" : ByteFormatting.string(app.leftoversSize))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(ByteFormatting.string(app.totalSize))
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .opacity(app.isAppleApp ? 0.6 : 1)
    }
}
