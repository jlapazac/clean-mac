import Foundation

/// Decides which paths may be moved to the Trash. Anything not explicitly allowed is protected:
/// only items inside the user's home folder and third-party `.app` bundles in the application
/// folders can be removed, and well-known folders themselves are always off limits.
public struct ProtectionPolicy: Sendable {
    public let homeDirectory: URL
    public let ownBundleURL: URL?
    public let applicationDirectories: [URL]

    private let homePath: String
    private let ownBundlePath: String?
    private let applicationPaths: [String]
    private let protectedExactPaths: Set<String>

    static let systemPaths = [
        "/", "/System", "/usr", "/bin", "/sbin", "/private", "/etc", "/var", "/tmp", "/opt",
        "/cores", "/dev", "/Volumes", "/Library", "/Applications", "/Applications/Utilities",
        "/System/Applications", "/Users",
    ]

    /// Folders directly under the home folder that must never be removed themselves.
    static let protectedHomeFolders = [
        "Library", "Documents", "Desktop", "Downloads", "Movies", "Music", "Pictures", "Public",
        "Applications", ".Trash", ".ssh",
    ]

    public init(
        homeDirectory: URL,
        ownBundleURL: URL?,
        applicationDirectories: [URL] = [URL(fileURLWithPath: "/Applications")]
    ) {
        self.homeDirectory = homeDirectory
        self.ownBundleURL = ownBundleURL
        self.applicationDirectories = applicationDirectories

        let home = Self.normalize(homeDirectory)
        homePath = home
        ownBundlePath = ownBundleURL.map(Self.normalize)
        applicationPaths = applicationDirectories.map(Self.normalize)

        var exact = Set(Self.systemPaths)
        exact.insert(home)
        for folder in Self.protectedHomeFolders {
            exact.insert(home + "/" + folder)
        }
        for kind in LeftoverKind.allCases {
            exact.insert(home + "/Library/" + kind.folderName)
        }
        for folder in ["Developer", "Mobile Documents", "CloudStorage", "Mail", "Messages",
                       "Keychains", "Photos", "Safari"] {
            exact.insert(home + "/Library/" + folder)
        }
        for app in applicationPaths {
            exact.insert(app)
            exact.insert(app + "/Utilities")
        }
        protectedExactPaths = exact
    }

    /// Returns `nil` when the item may be moved to the Trash, otherwise the reason (in Spanish).
    public func protectionReason(for url: URL) -> String? {
        let path = Self.normalize(url)

        if protectedExactPaths.contains(path) {
            return "Carpeta protegida del sistema o del usuario"
        }
        if let own = ownBundlePath, path == own || Self.isDescendant(path, of: own)
            || Self.isDescendant(own, of: path) {
            return "Es la propia CleanMac"
        }
        if path == homePath + "/.Trash" || Self.isDescendant(path, of: homePath + "/.Trash") {
            return "Ya está en la Papelera"
        }
        if Self.isDescendant(path, of: homePath) {
            return nil
        }
        if let base = applicationPaths.first(where: { Self.isDescendant(path, of: $0) }) {
            return applicationBundleReason(path, base: base)
        }
        return "Está fuera de la carpeta personal"
    }

    /// For paths in the application folders: `nil` for a third-party `.app` (top level or one
    /// sub-folder deep), a reason otherwise.
    private func applicationBundleReason(_ path: String, base: String) -> String? {
        let relative = path.dropFirst(base.count + 1).split(separator: "/")
        guard (1...2).contains(relative.count), relative.last?.hasSuffix(".app") == true else {
            return "Solo se pueden eliminar paquetes .app en Aplicaciones"
        }
        if relative.count == 2, relative.first?.hasSuffix(".app") == true {
            return "Está dentro de otra app"
        }
        let bundleID = Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier
        if let bundleID, bundleID.hasPrefix("com.apple.") {
            return "App del sistema de Apple"
        }
        return nil
    }

    /// Standardized absolute path with `..` removed and symlinks in parent folders resolved
    /// (the last component is kept as-is so a symlink is judged by its own location).
    public static func normalize(_ url: URL) -> String {
        let standardized = url.standardizedFileURL
        let name = standardized.lastPathComponent
        let parent = standardized.deletingLastPathComponent()
        if standardized.path == "/" { return "/" }
        let parentPath = parent.resolvingSymlinksInPath().path
        let joined = parentPath == "/" ? "/" + name : parentPath + "/" + name
        return joined.count > 1 && joined.hasSuffix("/") ? String(joined.dropLast()) : joined
    }

    static func isDescendant(_ path: String, of ancestor: String) -> Bool {
        if ancestor == "/" { return path != "/" }
        return path.hasPrefix(ancestor + "/")
    }
}
