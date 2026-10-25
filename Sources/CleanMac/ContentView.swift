import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
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
    @State private var section: SidebarSection? = .space
    @State private var space = SpaceViewModel()
    @State private var apps = AppsViewModel()
    @State private var cleanup = CleanupViewModel()

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            // Fill the column and pin content to the top; otherwise a long list's ideal height
            // grows the whole split view past the window and pushes everything out of sight.
            Group {
                switch section ?? .space {
                case .space: SpaceView(model: space)
                case .apps: AppsView(model: apps)
                case .cleanup: CleanupView(model: cleanup)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}
