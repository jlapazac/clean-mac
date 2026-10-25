import CleanMacCore
import SwiftUI

struct CleanupView: View {
    @Bindable var model: CleanupViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Datos regenerables").font(.title2.bold())
                            Text("Puedes liberar hasta \(ByteFormatting.string(model.cleanableTotal)) sin perder nada importante.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Volver a medir", systemImage: "arrow.clockwise", action: model.measureAll)
                            .disabled(!model.measuring.isEmpty)
                    }
                    if let result = model.lastResult { DeletionResultView(result: result) }
                    ForEach(model.categories) { category in
                        CategoryCard(
                            category: category,
                            isMeasuring: model.measuring.contains(category.id),
                            isSelected: model.selection.contains(category.id),
                            onToggle: { model.toggle(category) })
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                Text(model.selection.isEmpty
                     ? "Marca las categorías que quieres limpiar"
                     : "\(model.selection.count) categorías · \(ByteFormatting.string(model.selectedSize))")
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isPreparing || model.isDeleting { ProgressView().controlSize(.small) }
                Button("Limpiar…", systemImage: "trash", role: .destructive, action: model.requestCleanup)
                    .disabled(model.selection.isEmpty || model.isPreparing || model.isDeleting)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Limpieza")
        .onAppear(perform: model.loadIfNeeded)
        .sheet(item: Binding(
            get: { model.pendingDeletion.map(PendingBatch.init) },
            set: { if $0 == nil { model.pendingDeletion = nil } }
        )) { batch in
            ConfirmationSheet(
                title: "¿Limpiar las categorías seleccionadas?",
                items: batch.items,
                onConfirm: model.confirmDeletion,
                onCancel: { model.pendingDeletion = nil })
        }
    }
}

private struct CategoryCard: View {
    let category: CleanupCategory
    let isMeasuring: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if category.risk == .informational {
                Image(systemName: "info.circle").foregroundStyle(.blue).frame(width: 20)
            } else {
                Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .disabled(!category.isCleanable)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.title).font(.headline)
                    Text(category.risk.title)
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 1)
                        .background((category.risk == .low ? Color.green : Color.blue).opacity(0.15), in: Capsule())
                }
                Text(category.detail).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(category.paths, id: \.self) { url in
                    Button(url.path.replacingOccurrences(of: SystemServices.homeDirectory.path, with: "~")) {
                        SystemServices.revealInFinder(url)
                    }
                    .buttonStyle(.link)
                    .font(.caption.monospaced())
                    .disabled(!FileManager.default.fileExists(atPath: url.path))
                }
                if let instructions = category.instructions, category.exists {
                    Text(instructions)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            Spacer()
            Group {
                if isMeasuring {
                    ProgressView().controlSize(.small)
                } else if !category.exists {
                    Text("No encontrada").foregroundStyle(.tertiary)
                } else {
                    Text(ByteFormatting.string(category.size))
                        .font(.title3.monospacedDigit())
                }
            }
            .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .opacity(category.exists || isMeasuring ? 1 : 0.6)
    }
}
