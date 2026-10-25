import AppKit
import CleanMacCore

/// Moves items to the Trash like Finder does. Tries the plain FileManager call first; if macOS
/// denies it (e.g. apps installed by root), asks Finder to move the item, and Finder shows the
/// system authorization dialog (password or Touch ID). CleanMac never sees the credential, and
/// "Put Back" keeps working because Finder did the move.
struct WorkspaceTrasher: Trasher {
    func trashItem(at url: URL) async throws {
        do {
            try await FileManagerTrasher().trashItem(at: url)
        } catch let error as NSError where Self.isPermissionError(error) {
            let path = AppleScriptRunner.escape(url.path)
            _ = try await MainActor.run {
                try AppleScriptRunner.run("tell application \"Finder\" to delete (POSIX file \"\(path)\")")
            }
            if FileManager.default.fileExists(atPath: url.path) {
                throw AppleScriptError.failed("Finder no pudo moverlo a la Papelera")
            }
        }
    }

    static func isPermissionError(_ error: NSError) -> Bool {
        if [CocoaError.fileWriteNoPermission.rawValue, CocoaError.fileReadNoPermission.rawValue]
            .contains(error.code) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain {
            return underlying.code == Int(EPERM) || underlying.code == Int(EACCES)
        }
        return false
    }
}
