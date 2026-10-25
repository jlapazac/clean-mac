import CleanMacCore
import SwiftUI

/// One row in a confirmation list.
struct PendingDeletion: Identifiable, Hashable {
    let url: URL
    let size: Int64
    var id: URL { url }
}

/// Every deletion in the app goes through this sheet: it lists each path and the total, and
/// states that items go to the Trash.
struct ConfirmationSheet: View {
    let title: String
    let items: [PendingDeletion]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var total: Int64 { items.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            Text("Se moverán \(items.count) elementos a la Papelera (\(ByteFormatting.string(total))). Podrás recuperarlos desde la Papelera hasta que la vacíes.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(items) { item in
                HStack {
                    Text(item.url.path)
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(item.url.path)
                    Spacer()
                    SizeLabel(bytes: item.size)
                }
            }
            .frame(minHeight: 160, maxHeight: 320)

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Mover a la Papelera", role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(items.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 620)
    }
}

/// Summary shown after a deletion.
struct DeletionResultView: View {
    let result: DeletionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Movido a la Papelera: \(ByteFormatting.string(result.bytesFreed)) en \(result.trashed.count) elementos. El espacio se libera al vaciar la Papelera.",
                  systemImage: "trash")
            if !result.failures.isEmpty {
                Label("\(result.failures.count) elementos no se pudieron mover:", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                ForEach(result.failures, id: \.url) { failure in
                    Text("• \(failure.url.lastPathComponent): \(failure.reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
