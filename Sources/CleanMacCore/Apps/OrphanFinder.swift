import Foundation

/// Files in `~/Library` left by apps that are no longer installed, grouped by app identifier.
public struct OrphanGroup: Sendable, Identifiable, Hashable {
    /// App identifier (first three components, e.g. `com.vendor.app`).
    public let id: String
    public let confidence: MatchConfidence
    public let items: [Leftover]
    public let lastModified: Date?
    /// Why the group is only a possible orphan (nil when confidence is high).
    public let note: String?

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    public init(id: String, confidence: MatchConfidence, items: [Leftover], lastModified: Date?, note: String?) {
        self.id = id
        self.confidence = confidence
        self.items = items
        self.lastModified = lastModified
        self.note = note
    }
}

/// Detects leftovers whose name is an app identifier that no installed app (and no app known to
/// macOS) owns. Names that are not identifiers (e.g. `Application Support/Claude`) are skipped:
/// they cannot be attributed safely.
public struct OrphanFinder: Sendable {
    public let libraryDirectory: URL

    public init(libraryDirectory: URL) {
        self.libraryDirectory = libraryDirectory
    }

    /// Groups modified more recently than this may still be used by a tool without an app bundle.
    public static let recentUseInterval: TimeInterval = 30 * 24 * 3600

    public func orphans(
        installedBundleIDs: Set<String>,
        isKnownApp: @Sendable (String) -> Bool,
        now: Date = Date()
    ) async -> [OrphanGroup] {
        let installed = Set(installedBundleIDs.map { $0.lowercased() })
        var byID: [String: (display: String, items: [Leftover], modified: Date?)] = [:]

        for kind in LeftoverKind.allCases {
            let folder = libraryDirectory.appendingPathComponent(kind.folderName, isDirectory: true)
            var candidates = Self.children(of: folder)
            if kind == .preferences {
                candidates += Self.children(of: folder.appendingPathComponent("ByHost", isDirectory: true))
            }
            for url in candidates {
                if Task.isCancelled { return [] }
                guard let identifier = Self.bundleIdentifier(fromItemName: url.lastPathComponent, kind: kind)
                else { continue }
                let key = identifier.lowercased()
                guard !key.hasPrefix("com.apple."), !key.contains("com.apple"),
                      !Self.belongsToInstalled(key, installed: installed),
                      !isKnownApp(identifier)
                else { continue }

                let size = SizeCalculator.allocatedSize(of: url).size
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate
                let leftover = Leftover(url: url, kind: kind, size: size, confidence: .high,
                                        reason: "La app \(identifier) ya no está instalada")
                var entry = byID[key] ?? (identifier, [], nil)
                entry.items.append(leftover)
                // macOS touches container folders whenever they are accessed, so their dates say
                // nothing about when the app was last used.
                let isContainer = kind == .containers || kind == .groupContainers
                if !isContainer, let modified, modified > (entry.modified ?? .distantPast) {
                    entry.modified = modified
                }
                byID[key] = entry
            }
        }

        return byID.map { key, entry in
            let organization = key.split(separator: ".").prefix(2).joined(separator: ".")
            let sharesVendor = installed.contains { $0.hasPrefix(organization + ".") }
            let recentlyUsed = entry.modified.map { now.timeIntervalSince($0) < Self.recentUseInterval } ?? false
            let note: String? = if sharesVendor {
                "Comparte empresa (\(organization)) con una app instalada"
            } else if recentlyUsed {
                "Se modificó hace poco: puede usarlo una herramienta sin app"
            } else {
                nil
            }
            return OrphanGroup(
                id: entry.display,
                confidence: note == nil ? .high : .ambiguous,
                items: entry.items.sorted { $0.size > $1.size },
                lastModified: entry.modified,
                note: note)
        }
        .sorted { $0.totalSize != $1.totalSize ? $0.totalSize > $1.totalSize : $0.id < $1.id }
    }

    /// App identifier contained in a `~/Library` item name, or nil when the name is not one.
    public static func bundleIdentifier(fromItemName name: String, kind: LeftoverKind) -> String? {
        var value = name
        for suffix in [".plist", ".savedState", ".binarycookies"] where value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
        }
        if kind == .groupContainers {
            if let first = value.split(separator: ".").first, first.count == 10,
               first.allSatisfy({ $0.isUppercase || $0.isNumber }) {
                value = String(value.dropFirst(11))
            }
            for prefix in ["group.", "groups."] where value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
            }
        }

        var components = value.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        // ByHost preferences end with a host UUID.
        if let last = components.last, last.count >= 8, last.contains("-") || last.allSatisfy(\.isHexDigit),
           components.count > 3 {
            components.removeLast()
        }
        guard components.count >= 3,
              let tld = components.first, (2...6).contains(tld.count), tld.allSatisfy({ $0.isLowercase && $0.isLetter }),
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } })
        else { return nil }
        return components.prefix(3).joined(separator: ".")
    }

    /// True when `key` is an installed app's identifier, one of its helpers, or a parent of it.
    static func belongsToInstalled(_ key: String, installed: Set<String>) -> Bool {
        installed.contains { id in id == key || id.hasPrefix(key + ".") || key.hasPrefix(id + ".") }
    }

    private static func children(of folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
    }
}
