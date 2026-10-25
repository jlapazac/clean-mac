import Foundation
import Testing
@testable import CleanMacCore

@Suite struct ProtectionPolicyTests {
    let sandbox: Sandbox
    let policy: ProtectionPolicy

    init() throws {
        sandbox = try Sandbox()
        policy = ProtectionPolicy(
            homeDirectory: sandbox.home,
            ownBundleURL: sandbox.applications.appendingPathComponent("CleanMac.app"),
            applicationDirectories: [sandbox.applications])
    }

    @Test(arguments: ["/", "/System", "/System/Library/CoreServices", "/usr/bin", "/bin", "/sbin",
                      "/private", "/private/etc/hosts", "/etc", "/var", "/Library",
                      "/Library/Application Support", "/Applications", "/System/Applications/Mail.app",
                      "/Users"])
    func systemPathsAreProtected(_ path: String) {
        #expect(policy.protectionReason(for: URL(fileURLWithPath: path)) != nil)
    }

    @Test func homeAndItsStandardFoldersAreProtected() {
        let home = sandbox.home
        let protected = [
            home,
            home.appendingPathComponent("Library"),
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent(".Trash"),
            home.appendingPathComponent(".Trash/old.txt"),
        ]
        for url in protected {
            #expect(policy.protectionReason(for: url) != nil, "\(url.path) should be protected")
        }
    }

    @Test func pathWithDotDotCannotEscapeProtection() {
        let sneaky = sandbox.home.appendingPathComponent("Library/Caches/../../Library")
        #expect(policy.protectionReason(for: sneaky) != nil)
    }

    @Test func itemsInsideHomeAreAllowed() {
        let allowed = [
            sandbox.home.appendingPathComponent("Library/Caches/com.example.app"),
            sandbox.home.appendingPathComponent("Library/Containers/com.docker.docker"),
            sandbox.home.appendingPathComponent(".npm/_cacache"),
            sandbox.home.appendingPathComponent("Downloads/big.dmg"),
            sandbox.home.appendingPathComponent("Documents/old-project"),
        ]
        for url in allowed {
            #expect(policy.protectionReason(for: url) == nil, "\(url.path) should be allowed")
        }
    }

    @Test func thirdPartyAppsAreAllowed() throws {
        let app = try sandbox.makeApp("Foo", bundleID: "com.example.foo")
        let nested = try sandbox.makeApp(
            "Bar", bundleID: "com.example.bar",
            in: sandbox.applications.appendingPathComponent("Utilities"))
        #expect(policy.protectionReason(for: app) == nil)
        #expect(policy.protectionReason(for: nested) == nil)
    }

    @Test func appleAppsAreProtected() throws {
        let app = try sandbox.makeApp("Safari", bundleID: "com.apple.Safari")
        #expect(policy.protectionReason(for: app) != nil)
    }

    @Test func ownBundleAndItsAncestorsAreProtected() throws {
        let own = try sandbox.makeApp("CleanMac", bundleID: "dev.cleanmac.CleanMac")
        #expect(policy.protectionReason(for: own) != nil)
        #expect(policy.protectionReason(for: own.appendingPathComponent("Contents")) != nil)
    }

    @Test func contentsOfAppBundlesAndOtherFilesInApplicationsAreProtected() throws {
        let app = try sandbox.makeApp("Foo", bundleID: "com.example.foo")
        #expect(policy.protectionReason(for: app.appendingPathComponent("Contents/Info.plist")) != nil)
        let stray = try sandbox.makeFile("readme.txt", bytes: 10, in: sandbox.applications)
        #expect(policy.protectionReason(for: stray) != nil)
    }

    @Test func pathsOutsideHomeAreProtected() {
        let outside = sandbox.root.appendingPathComponent("elsewhere/file.txt")
        #expect(policy.protectionReason(for: outside) != nil)
    }
}
