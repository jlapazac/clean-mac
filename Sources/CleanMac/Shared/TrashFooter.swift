import AppKit
import CleanMacCore
import Observation
import SwiftUI

extension Notification.Name {
    /// Posted after CleanMac moved items to the Trash or emptied it.
    static let cleanMacTrashChanged = Notification.Name("CleanMacTrashChanged")
}

@MainActor
@Observable
final class TrashViewModel {
    private(set) var size: Int64?
    private(set) var isEmptying = false
    private(set) var message: String?
    var isConfirming = false

    func refresh() {
        let home = SystemServices.homeDirectory
        Task {
            size = await Task.detached(priority: .utility) { TrashLocation.size(home: home) }.value
        }
    }

    /// Empties the Trash through Finder (constitution I, v1.3.0): CleanMac never deletes
    /// permanently itself.
    func empty() {
        isEmptying = true
        message = nil
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            do {
                _ = try AppleScriptRunner.run("tell application \"Finder\" to empty trash")
                message = "Papelera vaciada"
            } catch {
                message = error.localizedDescription
            }
            isEmptying = false
            refresh()
            NotificationCenter.default.post(name: .cleanMacTrashChanged, object: nil)
        }
    }
}

/// Bottom of the sidebar: Trash size and "Vaciar Papelera…", visible from every section.
struct TrashFooter: View {
    @Bindable var model: TrashViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Label("Papelera", systemImage: (model.size ?? 0) > 0 ? "trash.fill" : "trash")
                Spacer()
                Text(model.size.map(ByteFormatting.string) ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help(model.size == nil ? "Sin Acceso total al disco no se puede medir la Papelera" : "")
            }
            Button(role: .destructive) {
                model.isConfirming = true
            } label: {
                HStack {
                    if model.isEmptying { ProgressView().controlSize(.small) }
                    Text("Vaciar Papelera…").frame(maxWidth: .infinity)
                }
            }
            .disabled(model.isEmptying || model.size == 0)
            if let message = model.message {
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(12)
        .onAppear(perform: model.refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cleanMacTrashChanged)) { _ in
            model.refresh()
        }
        .alert("¿Vaciar la Papelera?", isPresented: $model.isConfirming) {
            Button("Vaciar Papelera", role: .destructive, action: model.empty)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán de forma permanente \(model.size.map(ByteFormatting.string) ?? "todos los elementos"). Esta acción no se puede deshacer.")
        }
    }
}
