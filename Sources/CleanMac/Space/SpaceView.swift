import CleanMacCore
import SwiftUI

struct SpaceView: View {
    @Bindable var model: SpaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VolumeHeader(volume: model.volume)
                scanControls
                if let hidden = model.unaccountedSize {
                    Label("Analizado: \(ByteFormatting.string(model.scannedSize)) · Sistema macOS y datos protegidos que ninguna app puede leer: \(ByteFormatting.string(hidden))",
                          systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if model.summary != nil {
                    RestrictedBanner(model: model)
                }
                if let result = model.lastResult {
                    DeletionResultView(result: result)
                }
                if model.summary != nil { breadcrumb }
            }
            .padding()

            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if model.summary != nil { footer }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Espacio")
        .sheet(item: Binding(
            get: { model.pendingDeletion.map(PendingBatch.init) },
            set: { if $0 == nil { model.pendingDeletion = nil } }
        )) { batch in
            ConfirmationSheet(
                title: "¿Mover a la Papelera?",
                items: batch.items,
                onConfirm: model.confirmDeletion,
                onCancel: { model.pendingDeletion = nil })
        }
    }

    @ViewBuilder private var scanControls: some View {
        HStack(spacing: 12) {
            if model.state == .scanning {
                Button("Cancelar", systemImage: "stop.circle", action: model.cancelScan)
                ProgressView().controlSize(.small)
                VStack(alignment: .leading) {
                    Text("\(model.progress.filesScanned.formatted()) archivos · \(ByteFormatting.string(model.progress.bytesScanned))")
                        .monospacedDigit()
                    Text(model.progress.currentPath)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            } else {
                Button(model.summary == nil ? "Analizar" : "Volver a analizar",
                       systemImage: "magnifyingglass", action: model.startScan)
                    .buttonStyle(.borderedProminent)
                if let summary = model.summary {
                    Text("\(summary.fileCount.formatted()) archivos analizados en \(summary.duration.formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated)))")
                        .foregroundStyle(.secondary)
                }
                if case .failed(let message) = model.state {
                    Text(message).foregroundStyle(.red)
                }
            }
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            Button("Inicio") { model.goBack(to: -1) }
                .buttonStyle(.link)
            ForEach(Array(model.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                Button(crumb.name) { model.goBack(to: index) }
                    .buttonStyle(.link)
                    .disabled(index == model.breadcrumbs.count - 1)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if model.summary == nil {
            ContentUnavailableView {
                Label(model.state == .scanning ? "Analizando…" : "Descubre qué ocupa tu disco",
                      systemImage: "internaldrive")
            } description: {
                Text("Se analizan tu carpeta personal, Aplicaciones y las carpetas del sistema (estas últimas solo para consulta). Nada se borra sin tu confirmación y todo va a la Papelera.")
            }
        } else {
            List {
                ForEach(model.currentItems) { item in
                    DiskItemRow(
                        item: item,
                        total: model.currentTotal,
                        isSelected: model.selection.contains(item.url),
                        protectionReason: model.protectionReason(item),
                        onToggle: { model.toggle(item) },
                        onOpen: { model.open(item) })
                }
                if let node = model.currentNode, node.smallItemsCount > 0 {
                    HStack {
                        Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("Otros elementos pequeños (\(node.smallItemsCount))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        SizeLabel(bytes: node.smallItemsSize)
                    }
                    .padding(.leading, 28)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(model.selection.isEmpty
                 ? "Marca elementos para moverlos a la Papelera"
                 : "\(model.selection.count) seleccionados · \(ByteFormatting.string(model.selectedSize))")
                .foregroundStyle(.secondary)
            Spacer()
            if model.isDeleting { ProgressView().controlSize(.small) }
            Button("Mover a la Papelera…", systemImage: "trash", role: .destructive,
                   action: model.requestDeletion)
                .disabled(model.selection.isEmpty || model.isDeleting)
        }
        .padding()
        .background(.bar)
    }
}

/// Wraps the pending list so it can drive `.sheet(item:)`.
struct PendingBatch: Identifiable {
    let items: [PendingDeletion]
    var id: [URL] { items.map(\.url) }
}

private struct DiskItemRow: View {
    let item: DiskItem
    let total: Int64
    let isSelected: Bool
    let protectionReason: String?
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .labelsHidden()
                .disabled(protectionReason != nil)
                .help(protectionReason ?? "Seleccionar para mover a la Papelera")

            Image(nsImage: SystemServices.icon(for: item.url))
                .resizable().frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.name).lineLimit(1)
                    if item.isSkipped {
                        Text(item.isPrivilegedMeasurement ? "Medido como administrador" : "No analizado")
                            .font(.caption)
                            .foregroundStyle(item.isPrivilegedMeasurement ? Color.secondary : Color.orange)
                    }
                    if protectionReason != nil {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.tertiary)
                            .help(protectionReason ?? "")
                    }
                }
                SizeBar(fraction: total > 0 ? Double(item.size) / Double(total) : 0)
                    .frame(maxWidth: 260)
            }

            Spacer()
            SizeLabel(bytes: item.size)
                .frame(minWidth: 80, alignment: .trailing)

            if item.isDirectory && !item.isSkipped {
                Button(action: onOpen) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .help("Ver contenido")
            } else {
                Image(systemName: "chevron.right").hidden()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
        .contextMenu {
            Button("Mostrar en Finder") { SystemServices.revealInFinder(item.url) }
            if item.isDirectory && !item.isSkipped {
                Button("Ver contenido", action: onOpen)
            }
        }
    }
}

struct VolumeHeader: View {
    let volume: VolumeInfo?

    var body: some View {
        if let volume {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Disco de inicio").font(.headline)
                    Spacer()
                    Text("\(ByteFormatting.string(volume.availableCapacity)) disponibles de \(ByteFormatting.string(volume.totalCapacity))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                SizeBar(fraction: volume.usedFraction,
                        tint: volume.usedFraction > 0.9 ? .red : volume.usedFraction > 0.75 ? .orange : .accentColor)
                    .frame(height: 10)
                Text("Usado: \(ByteFormatting.string(volume.usedCapacity)) (\(Int(volume.usedFraction * 100)) %)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct RestrictedBanner: View {
    let model: SpaceViewModel

    var body: some View {
        let pending = model.pendingRestrictedPaths
        VStack(alignment: .leading, spacing: 8) {
            if !model.hasFullDiskAccess {
                HStack {
                    Image(systemName: "lock.shield").foregroundStyle(.orange)
                    Text("CleanMac no tiene Acceso total al disco: no puede ver los datos de otras apps en tu Library.")
                        .lineLimit(2)
                    Spacer()
                    Button("Abrir Ajustes", action: SystemServices.openFullDiskAccessSettings)
                }
            }
            if !pending.isEmpty {
                HStack {
                    Image(systemName: "touchid").foregroundStyle(.orange)
                    Text("\(pending.count) carpetas del sistema solo las puede leer un administrador.")
                        .lineLimit(2)
                    Spacer()
                    if model.isMeasuringRestricted {
                        ProgressView().controlSize(.small)
                    }
                    Button("Medir con contraseña o Touch ID", action: model.measureRestricted)
                        .disabled(model.isMeasuringRestricted)
                }
            }
            if let message = model.restrictedMessage {
                Text(message).font(.callout).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(model.hasFullDiskAccess && pending.isEmpty && model.restrictedMessage == nil ? 0 : 10)
        .background(.orange.opacity(model.hasFullDiskAccess && pending.isEmpty ? 0 : 0.1),
                    in: RoundedRectangle(cornerRadius: 8))
    }
}
