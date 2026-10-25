import AppKit

enum AppleScriptError: LocalizedError {
    case cancelled
    case automationDenied
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Cancelaste la autorización"
        case .automationDenied:
            "CleanMac no tiene permiso para controlar Finder. Actívalo en Ajustes del Sistema → Privacidad y seguridad → Automatización → CleanMac → Finder."
        case .failed(let message):
            message
        }
    }
}

/// Runs AppleScript in-process. Used only to delegate to macOS: Finder (move to Trash with its
/// own authorization dialog) and the system authorization dialog for read-only measurements.
@MainActor
enum AppleScriptRunner {
    static func run(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptError.failed("Script inválido")
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            switch number {
            case -128: throw AppleScriptError.cancelled
            case -1743: throw AppleScriptError.automationDenied
            default:
                throw AppleScriptError.failed(errorInfo[NSAppleScript.errorMessage] as? String ?? "Error \(number)")
            }
        }
        return result.stringValue ?? ""
    }

    nonisolated static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
