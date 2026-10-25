import AppKit
import CleanMacCore

/// Moves items to the Trash like Finder does. Tries the plain FileManager call first; if macOS
/// denies it (items owned by root, protected app bundles), falls back to NSWorkspace, which shows
/// the system's own authorization dialog. CleanMac never sees the password.
struct WorkspaceTrasher: Trasher {
    func trashItem(at url: URL) async throws {
        do {
            try await FileManagerTrasher().trashItem(at: url)
        } catch let error as NSError where Self.isPermissionError(error) {
            _ = try await NSWorkspace.shared.recycle([url])
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
