import Foundation
import Testing
@testable import CleanMacCore

@Suite struct AppInventoryTests {
    let sandbox: Sandbox

    init() throws { sandbox = try Sandbox() }

    @Test func readsBundlesTopLevelAndOneFolderDeep() async throws {
        try sandbox.makeApp("Foo", bundleID: "com.example.foo", version: "2.1", payloadBytes: 50_000)
        try sandbox.makeApp("Bar", bundleID: "com.example.bar",
                            in: sandbox.applications.appendingPathComponent("Utilities"))
        try sandbox.makeApp("Deep", bundleID: "com.example.deep",
                            in: sandbox.applications.appendingPathComponent("a/b"))
        try sandbox.makeFile("notes.txt", bytes: 10, in: sandbox.applications)

        let apps = await AppInventory(searchDirectories: [sandbox.applications]).installedApps()
        #expect(apps.map(\.name) == ["Bar", "Foo"])
        let foo = try #require(apps.first { $0.name == "Foo" })
        #expect(foo.bundleIdentifier == "com.example.foo")
        #expect(foo.version == "2.1")
        #expect(foo.executableName == "Foo")
        #expect(foo.bundleSize >= 50_000)
        #expect(!foo.isAppleApp)
    }

    @Test func detectsAppleApps() async throws {
        try sandbox.makeApp("Safari", bundleID: "com.apple.Safari")
        let apps = await AppInventory(searchDirectories: [sandbox.applications]).installedApps()
        #expect(apps.first?.isAppleApp == true)
        #expect(apps.first?.canUninstall == false)
    }

    @Test func appWithoutBundleIDIsListed() async throws {
        try sandbox.makeApp("Odd", bundleID: nil)
        let apps = await AppInventory(searchDirectories: [sandbox.applications]).installedApps()
        #expect(apps.count == 1)
        #expect(apps.first?.bundleIdentifier == nil)
    }

    @Test func missingSearchDirectoryIsIgnored() async {
        let apps = await AppInventory(
            searchDirectories: [sandbox.root.appendingPathComponent("nope")]).installedApps()
        #expect(apps.isEmpty)
    }
}
