import AppKit
import CleanMacCore

/// Thin wrappers over AppKit used by the views and view models.
@MainActor
enum SystemServices {
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Bundle locations of every running app, normalized for comparison.
    static func runningAppPaths() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap {
            $0.bundleURL.map { ProtectionPolicy.normalize($0) }
        })
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// The running bundle, or nil when launched with `swift run` (a bare executable).
    static var ownBundleURL: URL? {
        let url = Bundle.main.bundleURL
        return url.pathExtension == "app" ? url : nil
    }

    static let applicationDirectories = [
        URL(fileURLWithPath: "/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]

    static func makeDeletionService() -> DeletionService {
        DeletionService(policy: makePolicy(), trasher: WorkspaceTrasher())
    }

    static func makePolicy() -> ProtectionPolicy {
        ProtectionPolicy(
            homeDirectory: homeDirectory,
            ownBundleURL: ownBundleURL,
            applicationDirectories: applicationDirectories)
    }
}
