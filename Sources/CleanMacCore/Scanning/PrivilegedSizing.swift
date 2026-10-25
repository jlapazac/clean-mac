import Foundation

/// Builds and parses the read-only `du` command used to measure folders the user cannot read.
/// The command runs through the macOS authorization dialog (`do shell script … with
/// administrator privileges`); CleanMac never sees the credential.
public enum PrivilegedSizing {
    /// AppleScript source that asks macOS for authorization and runs `du -sk` on `paths`.
    public static func appleScript(for paths: [String]) -> String {
        // du exits non-zero if any path stays unreadable (e.g. SIP); report what it could measure.
        let command = "/usr/bin/du -sk -- " + paths.map(shellQuote).joined(separator: " ")
            + " 2>/dev/null; exit 0"
        let prompt = "CleanMac necesita tu autorización para medir carpetas del sistema. Solo se leerán tamaños; no se modificará nada."
        return "do shell script \"\(appleScriptEscape(command))\" with prompt \"\(appleScriptEscape(prompt))\" with administrator privileges"
    }

    /// Parses `du -sk` output ("<KiB>\t<path>" per line) into bytes per path.
    public static func parse(_ output: String) -> [String: Int64] {
        var sizes: [String: Int64] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            guard let tab = line.firstIndex(of: "\t"), let kib = Int64(line[..<tab]) else { continue }
            sizes[String(line[line.index(after: tab)...])] = kib * 1024
        }
        return sizes
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
