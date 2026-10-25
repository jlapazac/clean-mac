import CleanMacCore
import SwiftUI

struct OrphansView: View {
    @Bindable var model: OrphansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restos de apps desinstaladas").font(.title2.bold())
                        Text("Archivos en tu Library cuyo identificador no corresponde a ninguna app instalada ni conocida por macOS. Nada viene marcado: revisa antes de borrar.")
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    Spacer()
                    Button("Buscar de nuevo", systemImage: "arrow.clockwise", action: model.reload)
                        .disabled(model.isLoading)
                }
                if let result = model.lastResult { DeletionResultView(result: result) }
            }
            .padding()
            Divider()

            if model.isLoading {
                ProgressView("Buscando restos…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.groups.isEmpty && model.hasLoaded {
                ContentUnavailableView("Sin restos huérfanos", systemImage: "checkmark.seal",
                                       description: Text("No se encontraron archivos de apps desinstaladas."))
            } else {
                List {
                    ForEach(model.groups) { group in
                        OrphanGroupRow(group: group,
                                       isSelected: model.selection.contains(group.id),
                                       onToggle: { model.toggle(group) })
                    }
                }
            }

            HStack {
                Text(model.selection.isEmpty
                     ? "\(model.groups.count) apps · \(ByteFormatting.string(model.totalSize)) en total"
                     : "\(model.selection.count) seleccionadas · \(ByteFormatting.string(model.selectedSize))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Marcar los de confianza alta", action: model.selectHighConfidence)
                    .disabled(model.groups.isEmpty)
                if model.isDeleting { ProgressView().controlSize(.small) }
                Button("Mover a la Papelera…", systemImage: "trash", role: .destructive,
                       action: model.requestDeletion)
                    .disabled(model.selection.isEmpty || model.isDeleting)
            }
            .padding()
            .background(.bar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Huérfanos")
        .onAppear(perform: model.loadIfNeeded)
        .sheet(item: Binding(
            get: { model.pendingDeletion.map(PendingBatch.init) },
            set: { if $0 == nil { model.pendingDeletion = nil } }
        )) { batch in
            ConfirmationSheet(
                title: "¿Mover los restos a la Papelera?",
                items: batch.items,
                onConfirm: model.confirmDeletion,
                onCancel: { model.pendingDeletion = nil })
        }
    }
}

private struct OrphanGroupRow: View {
    let group: OrphanGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        DisclosureGroup {
            ForEach(group.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.kind.title).font(.callout)
                        Text(item.url.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    SizeLabel(bytes: item.size)
                }
                .contextMenu {
                    Button("Mostrar en Finder") { SystemServices.revealInFinder(item.url) }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                    .labelsHidden()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(group.id).lineLimit(1)
                        Text(group.confidence == .high ? "Confianza alta" : "Posible")
                            .font(.caption2).padding(.horizontal, 6).padding(.vertical, 1)
                            .background((group.confidence == .high ? Color.green : Color.orange).opacity(0.2),
                                        in: Capsule())
                            .help(group.note ?? "Ninguna app instalada usa este identificador")
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                SizeLabel(bytes: group.totalSize)
            }
        }
    }

    private var subtitle: String {
        var parts = [group.items.count == 1 ? "1 elemento" : "\(group.items.count) elementos"]
        if let date = group.lastModified {
            parts.append("modificado \(date.formatted(.relative(presentation: .named)))")
        }
        if let note = group.note { parts.append(note) }
        return parts.joined(separator: " · ")
    }
}
