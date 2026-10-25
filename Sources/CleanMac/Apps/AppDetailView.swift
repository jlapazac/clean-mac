import CleanMacCore
import SwiftUI

struct AppDetailView: View {
    @Bindable var model: AppsViewModel
    let app: InstalledApp

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding()
            if let message = model.message {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }
            if let result = model.lastResult {
                DeletionResultView(result: result).padding(.horizontal)
            }
            Divider().padding(.top, 8)
            List {
                Section("Paquete de la app") {
                    ItemRow(url: app.url, title: app.name + ".app", subtitle: app.url.path,
                            size: app.bundleSize, isOn: .constant(true), isLocked: true)
                }
                Section {
                    if model.leftoversPending.contains(app.id) {
                        HStack { ProgressView().controlSize(.small); Text("Buscando restos…") }
                    } else if app.leftovers.isEmpty {
                        Text(app.bundleIdentifier == nil
                             ? "La app no tiene identificador; no se buscan restos."
                             : "No se encontraron restos en tu Library.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(app.leftovers) { leftover in
                        ItemRow(
                            url: leftover.url,
                            title: "\(leftover.kind.title) · \(leftover.url.lastPathComponent)",
                            subtitle: leftover.reason + (leftover.confidence == .ambiguous ? " — revisa antes de borrar" : ""),
                            size: leftover.size,
                            isOn: Binding(
                                get: { model.isLeftoverSelected(leftover, in: app) },
                                set: { _ in model.toggleLeftover(leftover, in: app) }),
                            isLocked: false,
                            isAmbiguous: leftover.confidence == .ambiguous)
                    }
                } header: {
                    Text("Restos en ~/Library (\(ByteFormatting.string(app.leftoversSize + app.possibleLeftoversSize)))")
                }
            }
            Divider()
            footer.padding()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: SystemServices.icon(for: app.url))
                .resizable().frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.title2.bold())
                Text([app.version.map { "Versión \($0)" }, app.bundleIdentifier]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Tamaño total: \(ByteFormatting.string(app.totalSize))")
                    .font(.headline)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            if app.isAppleApp {
                Label("App del sistema de Apple: no se puede desinstalar", systemImage: "lock")
                    .foregroundStyle(.secondary)
            } else if app.isSelf {
                Label("Es CleanMac", systemImage: "lock").foregroundStyle(.secondary)
            } else if app.isRunning {
                Label("La app está abierta; ciérrala para desinstalarla", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
            } else {
                Text("Se liberarán \(ByteFormatting.string(model.removalSize(for: app))) al vaciar la Papelera")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isDeleting { ProgressView().controlSize(.small) }
            Button("Desinstalar…", systemImage: "trash", role: .destructive) {
                model.requestUninstall(app)
            }
            .disabled(app.isAppleApp || app.isSelf || model.isDeleting
                      || model.leftoversPending.contains(app.id))
        }
    }
}

private struct ItemRow: View {
    let url: URL
    let title: String
    let subtitle: String
    let size: Int64
    @Binding var isOn: Bool
    let isLocked: Bool
    var isAmbiguous = false

    var body: some View {
        HStack(alignment: .top) {
            Toggle("", isOn: $isOn).labelsHidden().disabled(isLocked)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title).lineLimit(1)
                    if isAmbiguous {
                        Text("Posible resto")
                            .font(.caption2).padding(.horizontal, 4)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(url.path).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            SizeLabel(bytes: size)
        }
        .contextMenu {
            Button("Mostrar en Finder") { SystemServices.revealInFinder(url) }
        }
    }
}
