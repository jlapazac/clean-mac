import Foundation
import Testing
@testable import CleanMacCore

@Suite struct PrivilegedSizingTests {
    @Test func scriptIsReadOnlyDuWithAdministratorPrivileges() {
        let script = PrivilegedSizing.appleScript(for: ["/private/var/db", "/Library/Foo"])
        #expect(script.hasPrefix("do shell script \"/usr/bin/du -sk -- '/private/var/db' '/Library/Foo'"))
        #expect(script.hasSuffix("with administrator privileges"))
        #expect(!script.contains("rm "))
    }

    @Test func pathsWithQuotesAreEscaped() {
        let script = PrivilegedSizing.appleScript(for: [#"/tmp/it's "odd""#])
        // Shell single-quote escaping, then AppleScript string escaping of the double quotes.
        #expect(script.contains(#"'/tmp/it'\\''s \"odd\"'"#))
    }

    @Test func parsesDuOutput() {
        let sizes = PrivilegedSizing.parse("2048\t/private/var/db\n10\t/Library/With Space\nbad line\n")
        #expect(sizes == ["/private/var/db": 2_097_152, "/Library/With Space": 10_240])
    }

    @Test func unreadablePathsAreReported() async throws {
        let sandbox = try Sandbox()
        let locked = try sandbox.makeDirectory("locked")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        let summary = try await DiskScanner(minimumItemSize: 1).scan(roots: [sandbox.home]) { _ in }
        #expect(summary.unreadablePaths == [locked.path])
    }
}
