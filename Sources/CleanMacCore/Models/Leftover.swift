import Foundation

/// The `~/Library` folder a leftover was found in.
public enum LeftoverKind: String, Sendable, CaseIterable {
    case applicationSupport = "Application Support"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case caches = "Caches"
    case preferences = "Preferences"
    case logs = "Logs"
    case savedState = "Saved Application State"
    case httpStorages = "HTTPStorages"
    case webKit = "WebKit"
    case cookies = "Cookies"
    case launchAgents = "LaunchAgents"

    /// Folder name inside `~/Library`.
    public var folderName: String { rawValue }

    public var title: String {
        switch self {
        case .applicationSupport: "Datos de la app"
        case .containers: "Contenedor"
        case .groupContainers: "Contenedor de grupo"
        case .caches: "Caché"
        case .preferences: "Preferencias"
        case .logs: "Registros"
        case .savedState: "Estado guardado"
        case .httpStorages: "Almacenamiento HTTP"
        case .webKit: "Datos web"
        case .cookies: "Cookies"
        case .launchAgents: "Agente de inicio"
        }
    }
}

public enum MatchConfidence: Sendable, Equatable {
    /// Matched by bundle identifier; selected by default.
    case high
    /// Matched by name or organization prefix; unselected by default.
    case ambiguous
}

/// A file or folder in `~/Library` that belongs (or may belong) to an app.
public struct Leftover: Sendable, Identifiable, Hashable {
    public let id: URL
    public let kind: LeftoverKind
    public let size: Int64
    public let confidence: MatchConfidence
    public let reason: String

    public var url: URL { id }

    public init(url: URL, kind: LeftoverKind, size: Int64, confidence: MatchConfidence, reason: String) {
        self.id = url
        self.kind = kind
        self.size = size
        self.confidence = confidence
        self.reason = reason
    }
}
