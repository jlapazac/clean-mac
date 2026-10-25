import Foundation
import Testing
@testable import CleanMacCore

@Suite struct OrphanFinderTests {
    let sandbox: Sandbox
    let finder: OrphanFinder

    init() throws {
        sandbox = try Sandbox()
        finder = OrphanFinder(libraryDirectory: sandbox.library)
    }

    func id(_ name: String, _ kind: LeftoverKind = .applicationSupport) -> String? {
        OrphanFinder.bundleIdentifier(fromItemName: name, kind: kind)
    }

    @Test func extractsIdentifiersFromItemNames() {
        #expect(id("com.old.app") == "com.old.app")
        #expect(id("com.old.app.plist", .preferences) == "com.old.app")
        #expect(id("com.old.app.helper.plist", .preferences) == "com.old.app")
        #expect(id("com.old.app.1A2B3C4D-1111-2222-3333-444455556666.plist", .preferences) == "com.old.app")
        #expect(id("com.old.app.savedState", .savedState) == "com.old.app")
        #expect(id("com.old.app.binarycookies", .cookies) == "com.old.app")
        #expect(id("ABCDE12345.com.old.app", .groupContainers) == "com.old.app")
        #expect(id("group.com.old.app", .groupContainers) == "com.old.app")
        #expect(id("243LU875E5.groups.com.apple.podcasts", .groupContainers) == "com.apple.podcasts")
    }

    @Test func ignoresNamesThatAreNotIdentifiers() {
        #expect(id("Claude") == nil)
        #expect(id("Google") == nil)
        #expect(id("com.two") == nil)
        #expect(id("My App 1.2.3") == nil)
        #expect(id("Some.Thing.Here") == nil)
    }

    @Test func findsOrphansAndGroupsThem() async throws {
        try sandbox.makeFile("Library/Application Support/com.old.app/data.bin", bytes: 200_000)
        try sandbox.makeFile("Library/Caches/com.old.app/c.bin", bytes: 50_000)
        try sandbox.makeFile("Library/Preferences/com.old.app.plist", bytes: 100)
        try sandbox.makeFile("Library/Caches/com.small.tool/x", bytes: 4_096)

        let groups = await finder.orphans(installedBundleIDs: [], isKnownApp: { _ in false },
                                          now: Date().addingTimeInterval(365 * 24 * 3600))
        #expect(groups.map(\.id) == ["com.old.app", "com.small.tool"])
        let old = try #require(groups.first)
        #expect(old.items.count == 3)
        #expect(old.totalSize >= 254_096)
        #expect(old.confidence == .high)
        #expect(old.lastModified != nil)
        #expect(old.items.allSatisfy { $0.url.path.hasPrefix(sandbox.library.path + "/") })
    }

    @Test func installedAppsAndTheirHelpersAreNotOrphans() async throws {
        try sandbox.makeDirectory("Library/Application Support/com.docker.docker")
        try sandbox.makeDirectory("Library/Caches/com.docker.docker.helper")
        try sandbox.makeDirectory("Library/Caches/com.microsoft.word")
        try sandbox.makeDirectory("Library/Caches/com.vendor.suite")
        let groups = await finder.orphans(
            installedBundleIDs: ["com.docker.docker", "com.microsoft.Word", "com.vendor.suite.editor"],
            isKnownApp: { _ in false })
        #expect(groups.isEmpty)
    }

    @Test func appleItemsAreNeverListed() async throws {
        try sandbox.makeDirectory("Library/Caches/com.apple.Safari")
        try sandbox.makeDirectory("Library/Group Containers/group.com.apple.notes")
        try sandbox.makeDirectory("Library/Group Containers/243LU875E5.groups.com.apple.podcasts")
        let groups = await finder.orphans(installedBundleIDs: [], isKnownApp: { _ in false })
        #expect(groups.isEmpty)
    }

    @Test func appsKnownToMacOSAreNotOrphans() async throws {
        try sandbox.makeDirectory("Library/Caches/org.homebrew.tool")
        let groups = await finder.orphans(installedBundleIDs: [], isKnownApp: { $0 == "org.homebrew.tool" })
        #expect(groups.isEmpty)
    }

    @Test func containerDatesAreIgnored() async throws {
        let prefs = try sandbox.makeFile("Library/Preferences/com.old.app.plist", bytes: 10)
        try sandbox.makeDirectory("Library/Containers/com.old.app")
        let old = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: prefs.path)
        let groups = await finder.orphans(installedBundleIDs: [], isKnownApp: { _ in false })
        #expect(groups.first?.lastModified == old)

        try sandbox.makeDirectory("Library/Group Containers/ABCDE12345.com.only.container")
        let again = await finder.orphans(installedBundleIDs: [], isKnownApp: { _ in false })
        #expect(again.first { $0.id == "com.only.container" }?.lastModified == nil)
    }

    @Test func sharedVendorMakesConfidencePossible() async throws {
        try sandbox.makeDirectory("Library/Caches/com.microsoft.teams2")
        let groups = await finder.orphans(installedBundleIDs: ["com.microsoft.Word"], isKnownApp: { _ in false })
        #expect(groups.first?.confidence == .ambiguous)
        #expect(groups.first?.note?.contains("com.microsoft") == true)
    }

    @Test func recentlyModifiedGroupsArePossible() async throws {
        try sandbox.makeFile("Library/Preferences/com.cli.tool.plist", bytes: 10)
        let groups = await finder.orphans(installedBundleIDs: [], isKnownApp: { _ in false })
        #expect(groups.first?.confidence == .ambiguous)
        #expect(groups.first?.note != nil)
    }
}
