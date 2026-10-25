import Foundation

/// A throwaway directory tree for tests. Removed on deinit.
final class Sandbox {
    let root: URL
    let home: URL
    let applications: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanMacTests-\(UUID().uuidString)", isDirectory: true)
        // Resolve /var → /private/var so paths compare equal to what the code sees.
        root = base.resolvingSymlinksInPath()
        home = root.appendingPathComponent("home", isDirectory: true)
        applications = root.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    var library: URL { home.appendingPathComponent("Library", isDirectory: true) }

    @discardableResult
    func makeDirectory(_ path: String, in base: URL? = nil) throws -> URL {
        let url = (base ?? home).appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes a file of `bytes` non-zero bytes, creating parent folders as needed.
    @discardableResult
    func makeFile(_ path: String, bytes: Int, in base: URL? = nil) throws -> URL {
        let url = (base ?? home).appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    /// Creates a minimal `.app` bundle with an Info.plist.
    @discardableResult
    func makeApp(
        _ name: String,
        bundleID: String?,
        version: String = "1.0",
        payloadBytes: Int = 8192,
        in base: URL? = nil
    ) throws -> URL {
        let app = (base ?? applications).appendingPathComponent("\(name).app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        var info: [String: Any] = [
            "CFBundleName": name,
            "CFBundleExecutable": name,
            "CFBundleShortVersionString": version,
            "CFBundlePackageType": "APPL",
        ]
        if let bundleID { info["CFBundleIdentifier"] = bundleID }
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        try Data(repeating: 0xCD, count: payloadBytes)
            .write(to: contents.appendingPathComponent("MacOS/\(name)"))
        return app
    }
}
