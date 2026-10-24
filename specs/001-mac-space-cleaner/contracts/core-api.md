# Contract: CleanMacCore public API

Interfaz que la UI consume. Todos los tipos de entrada/salida están en `data-model.md`.

```swift
// Safety
public protocol Trasher: Sendable {
    func trashItem(at url: URL) throws
}
public struct FileManagerTrasher: Trasher { public init() }

public struct ProtectionPolicy: Sendable {
    public init(homeDirectory: URL, ownBundleURL: URL?)
    /// nil si la ruta es borrable; si no, motivo legible en español.
    public func protectionReason(for url: URL) -> String?
}

public struct DeletionService: Sendable {
    public init(policy: ProtectionPolicy, trasher: Trasher = FileManagerTrasher())
    /// Mueve a la Papelera; nunca borra permanentemente. Mide tamaños antes de mover.
    public func trash(_ urls: [URL]) async -> DeletionResult
}

// Scanning
public struct VolumeInfoProvider: Sendable {
    public static func startupVolume() throws -> VolumeInfo
}

public enum SizeCalculator {
    /// Tamaño asignado total (recursivo), sin seguir symlinks. Errores contados en `unreadable`.
    public static func allocatedSize(of url: URL) -> (size: Int64, unreadable: Int)
}

public struct DiskScanner: Sendable {
    public init(minimumItemSize: Int64 = 1_000_000, excludedPaths: [URL] = [])
    /// Cancelable vía cancelación de la Task. Progreso emitido por `progress`.
    public func scan(roots: [URL],
                     progress: @escaping @Sendable (ScanProgress) -> Void) async throws -> ScanSummary
    /// Re-escanea un único subárbol (tras borrar elementos).
    public func scanItem(at url: URL) async throws -> DiskItem
}

// Apps
public struct AppInventory: Sendable {
    public init(searchDirectories: [URL])
    public func installedApps() async -> [InstalledApp]   // sin restos, con bundleSize
}

public struct LeftoverFinder: Sendable {
    public init(libraryDirectory: URL)
    public func leftovers(for app: InstalledApp,
                          otherBundleIDs: Set<String>) async -> [Leftover]
}

// Cleanup
public struct CleanupCatalog: Sendable {
    public init(homeDirectory: URL)
    public func categories() -> [CleanupCategory]           // sin medir
    public func measure(_ category: CleanupCategory) async -> CleanupCategory
    /// Hijos directos de las rutas de la categoría (lo que se moverá a la Papelera).
    public func itemsToClean(in category: CleanupCategory) -> [URL]
}

// Support
public enum ByteFormatting {
    public static func string(_ bytes: Int64) -> String   // "35,2 GB"
}
```

## Garantías verificadas por tests

1. `DeletionService.trash` nunca invoca al `Trasher` con una ruta para la que
   `protectionReason != nil`; la reporta como fallo.
2. `ProtectionPolicy` protege las rutas de research.md §R8.
3. `LeftoverFinder` clasifica según FR-009 y nunca devuelve rutas fuera de `libraryDirectory`.
4. `DiskScanner` respeta el umbral de 1 MB, la suma de tamaños y la cancelación.
5. `CleanupCatalog.itemsToClean` devuelve hijos, nunca la raíz de la categoría; Docker devuelve `[]`.
