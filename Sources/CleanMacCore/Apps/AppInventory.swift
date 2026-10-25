import Foundation

/// Lists `.app` bundles in the given folders, at the top level and one sub-folder deep
/// (e.g. `/Applications/Utilities`).
public struct AppInventory: Sendable {
    public let searchDirectories: [URL]

    public init(searchDirectories: [URL]) {
        self.searchDirectories = searchDirectories
    }

    public func installedApps() async -> [InstalledApp] {
        let bundles = bundleURLs()
        let apps = await withTaskGroup(of: InstalledApp?.self) { group in
            for url in bundles {
                group.addTask { Self.makeApp(at: url) }
            }
            var collected: [InstalledApp] = []
            for await app in group {
                if let app { collected.append(app) }
            }
            return collected
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func bundleURLs() -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        func add(_ url: URL) {
            if seen.insert(url.standardizedFileURL.resolvingSymlinksInPath().path).inserted {
                result.append(url)
            }
        }
        for directory in searchDirectories {
            for child in Self.children(of: directory) {
                if child.pathExtension == "app" {
                    add(child)
                } else if Self.isDirectory(child) {
                    Self.children(of: child).filter { $0.pathExtension == "app" }.forEach(add)
                }
            }
        }
        return result
    }

    static func makeApp(at url: URL) -> InstalledApp? {
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        let bundleID = info["CFBundleIdentifier"] as? String
        let fileName = url.deletingPathExtension().lastPathComponent
        return InstalledApp(
            url: url,
            name: fileName,
            bundleIdentifier: bundleID,
            executableName: info["CFBundleExecutable"] as? String,
            version: info["CFBundleShortVersionString"] as? String,
            bundleSize: SizeCalculator.allocatedSize(of: url).size,
            isAppleApp: bundleID?.hasPrefix("com.apple.") ?? false)
    }

    private static func children(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
