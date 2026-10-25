import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case space, apps, cleanup
    var id: String { rawValue }

    var title: String {
        switch self {
        case .space: "Espacio"
        case .apps: "Aplicaciones"
        case .cleanup: "Limpieza"
        }
    }

    var icon: String {
        switch self {
        case .space: "chart.bar.doc.horizontal"
        case .apps: "app.badge"
        case .cleanup: "sparkles"
        }
    }
}

struct ContentView: View {
    @State private var section: Section? = .space

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch section ?? .space {
            case .space: Text("Espacio")
            case .apps: Text("Aplicaciones")
            case .cleanup: Text("Limpieza")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
