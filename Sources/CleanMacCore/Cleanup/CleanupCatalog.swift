import Foundation

/// Predefined groups of regenerable data. Cleaning a category moves the *contents* of its
/// folders to the Trash; the folders themselves stay.
public struct CleanupCatalog: Sendable {
    public let homeDirectory: URL

    public init(homeDirectory: URL) {
        self.homeDirectory = homeDirectory
    }

    public func categories() -> [CleanupCategory] {
        [
            CleanupCategory(
                id: "npm",
                title: "Caché de npm",
                detail: "Paquetes descargados por npm y npx. Se vuelven a descargar cuando hagan falta; la próxima instalación puede tardar más.",
                paths: [path(".npm/_cacache"), path(".npm/_npx")],
                risk: .low),
            CleanupCategory(
                id: "userCache",
                title: "Caché general (~/.cache)",
                detail: "Cachés de herramientas de desarrollo (pip, Hugging Face, Puppeteer, etc.). Se regeneran automáticamente.",
                paths: [path(".cache")],
                risk: .low),
            CleanupCategory(
                id: "libraryCaches",
                title: "Cachés de apps",
                detail: "Archivos temporales que las apps guardan en ~/Library/Caches. Las apps los regeneran; conviene cerrarlas antes.",
                paths: [path("Library/Caches")],
                risk: .low),
            CleanupCategory(
                id: "xcodeDerived",
                title: "Datos derivados de Xcode",
                detail: "Compilaciones intermedias e índices de Xcode. Se regeneran en la siguiente compilación.",
                paths: [path("Library/Developer/Xcode/DerivedData")],
                risk: .low),
            CleanupCategory(
                id: "logs",
                title: "Registros de usuario",
                detail: "Archivos de registro de apps en ~/Library/Logs. Solo sirven para diagnosticar problemas.",
                paths: [path("Library/Logs")],
                risk: .low),
            CleanupCategory(
                id: "docker",
                title: "Docker",
                detail: "Disco virtual con imágenes, contenedores y volúmenes de Docker. No se debe borrar como archivo: se corrompería Docker.",
                paths: [path("Library/Containers/com.docker.docker")],
                risk: .informational,
                instructions: """
                Para recuperar espacio desde Docker:
                1. En una terminal: docker system prune -a --volumes (borra imágenes, contenedores parados, redes y volúmenes sin usar).
                2. O en Docker Desktop → Troubleshoot → Clean / Purge data.
                3. Para que el disco virtual ocupe menos: Docker Desktop → Settings → Resources → reduce "Virtual disk limit".
                """),
        ]
    }

    public func measure(_ category: CleanupCategory) async -> CleanupCategory {
        var measured = category
        measured.exists = false
        measured.size = 0
        for url in category.paths where FileManager.default.fileExists(atPath: url.path) {
            measured.exists = true
            measured.size += SizeCalculator.allocatedSize(of: url).size
        }
        return measured
    }

    /// Direct children of the category's folders: what will be moved to the Trash.
    public func itemsToClean(in category: CleanupCategory) -> [URL] {
        guard category.risk != .informational else { return [] }
        return category.paths.flatMap { folder in
            (try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: [])) ?? []
        }
    }

    private func path(_ relative: String) -> URL {
        homeDirectory.appendingPathComponent(relative, isDirectory: true)
    }
}
