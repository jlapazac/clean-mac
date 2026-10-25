import Foundation

/// Finds the files an app leaves in `~/Library`. Only direct children of the standard folders
/// are considered, so results always stay inside the library folder.
public struct LeftoverFinder: Sendable {
    public let libraryDirectory: URL

    /// Organization prefixes too broad to suggest anything from.
    static let genericOrganizations: Set<String> = ["com.apple"]

    public init(libraryDirectory: URL) {
        self.libraryDirectory = libraryDirectory
    }

    public func leftovers(for app: InstalledApp, otherBundleIDs: Set<String>) async -> [Leftover] {
        guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { return [] }
        let matcher = Matcher(
            bundleID: bundleID,
            names: [app.name, app.executableName].compactMap { $0 }.filter { $0.count >= 3 },
            otherBundleIDs: otherBundleIDs.subtracting([bundleID]))

        var results: [Leftover] = []
        for kind in LeftoverKind.allCases {
            let folder = libraryDirectory.appendingPathComponent(kind.folderName, isDirectory: true)
            var candidates = children(of: folder)
            if kind == .preferences {
                candidates += children(of: folder.appendingPathComponent("ByHost", isDirectory: true))
            }
            for url in candidates {
                if Task.isCancelled { return results }
                guard let (confidence, reason) = matcher.match(url.lastPathComponent, kind: kind) else {
                    continue
                }
                let size = SizeCalculator.allocatedSize(of: url).size
                results.append(Leftover(url: url, kind: kind, size: size, confidence: confidence, reason: reason))
            }
        }
        return results.sorted {
            if $0.confidence != $1.confidence { return $0.confidence == .high }
            return $0.size > $1.size
        }
    }

    private func children(of folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    struct Matcher {
        let bundleID: String
        let names: [String]
        let otherBundleIDs: Set<String>
        let organization: String?

        init(bundleID: String, names: [String], otherBundleIDs: Set<String>) {
            self.bundleID = bundleID
            self.names = names
            self.otherBundleIDs = otherBundleIDs
            let parts = bundleID.split(separator: ".")
            let org = parts.count >= 3 ? parts.prefix(2).joined(separator: ".") : nil
            organization = org.flatMap { LeftoverFinder.genericOrganizations.contains($0) ? nil : $0 }
        }

        func match(_ name: String, kind: LeftoverKind) -> (MatchConfidence, String)? {
            if belongsToAnotherApp(name) { return nil }

            if name == bundleID || name.hasPrefix(bundleID + ".") {
                return (.high, "Nombre igual al identificador \(bundleID)")
            }
            if kind == .groupContainers && name.hasSuffix("." + bundleID) {
                return (.high, "Contenedor de grupo del identificador \(bundleID)")
            }

            let stem = (name as NSString).deletingPathExtension
            if let appName = names.first(where: {
                name.caseInsensitiveCompare($0) == .orderedSame || stem.caseInsensitiveCompare($0) == .orderedSame
            }) {
                return (.ambiguous, "Coincide con el nombre de la app «\(appName)»")
            }
            if let org = organization,
               name.hasPrefix(org + ".") || name.hasSuffix("." + org) || name.contains("." + org + ".") {
                return (.ambiguous, "Comparte el prefijo de organización \(org)")
            }
            return nil
        }

        /// True when the item is an exact match for a different installed app with a more
        /// specific identifier (e.g. `com.example.foo.helper` while matching `com.example.foo`).
        private func belongsToAnotherApp(_ name: String) -> Bool {
            otherBundleIDs.contains { other in
                name == other || name.hasPrefix(other + ".") || name.hasSuffix("." + other)
            }
        }
    }
}
