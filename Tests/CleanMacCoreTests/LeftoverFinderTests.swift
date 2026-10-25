import Foundation
import Testing
@testable import CleanMacCore

@Suite struct LeftoverFinderTests {
    let sandbox: Sandbox
    let finder: LeftoverFinder

    init() throws {
        sandbox = try Sandbox()
        finder = LeftoverFinder(libraryDirectory: sandbox.library)
    }

    func app(_ name: String, _ id: String?) -> InstalledApp {
        InstalledApp(url: sandbox.applications.appendingPathComponent("\(name).app"), name: name,
                     bundleIdentifier: id, executableName: name, version: "1", bundleSize: 0,
                     isAppleApp: false)
    }

    func names(_ leftovers: [Leftover], _ confidence: MatchConfidence) -> Set<String> {
        Set(leftovers.filter { $0.confidence == confidence }.map(\.url.lastPathComponent))
    }

    @Test func exactBundleIDMatchesAreHighConfidence() async throws {
        try sandbox.makeFile("Library/Containers/com.docker.docker/Data/disk.raw", bytes: 8_192)
        try sandbox.makeFile("Library/Application Support/com.docker.docker/x", bytes: 100)
        try sandbox.makeFile("Library/Preferences/com.docker.docker.plist", bytes: 100)
        try sandbox.makeFile("Library/Preferences/ByHost/com.docker.docker.ABC123.plist", bytes: 100)
        try sandbox.makeFile("Library/Saved Application State/com.docker.docker.savedState/s", bytes: 100)
        try sandbox.makeFile("Library/Cookies/com.docker.docker.binarycookies", bytes: 100)
        try sandbox.makeFile("Library/Group Containers/9BNSXJN65R.com.docker.docker/g", bytes: 100)

        let found = await finder.leftovers(for: app("Docker", "com.docker.docker"), otherBundleIDs: [])
        #expect(names(found, .high) == [
            "com.docker.docker", "com.docker.docker.plist", "com.docker.docker.ABC123.plist",
            "com.docker.docker.savedState", "com.docker.docker.binarycookies",
            "9BNSXJN65R.com.docker.docker",
        ])
        #expect(found.contains { $0.kind == .containers && $0.size >= 8_192 })
        #expect(found.allSatisfy { !$0.reason.isEmpty })
    }

    @Test func nameAndOrganizationMatchesAreAmbiguous() async throws {
        try sandbox.makeDirectory("Library/Application Support/Docker Desktop")
        try sandbox.makeDirectory("Library/Application Support/Docker")
        try sandbox.makeDirectory("Library/Caches/com.docker.helper")
        try sandbox.makeDirectory("Library/Group Containers/group.com.docker")

        let found = await finder.leftovers(for: app("Docker", "com.docker.docker"), otherBundleIDs: [])
        #expect(names(found, .ambiguous) == ["Docker", "com.docker.helper", "group.com.docker"])
        #expect(names(found, .high).isEmpty)
    }

    @Test func itemsOfOtherInstalledAppsAreExcluded() async throws {
        try sandbox.makeDirectory("Library/Caches/com.example.foo")
        try sandbox.makeDirectory("Library/Caches/com.example.foo.helper")
        try sandbox.makeFile("Library/Preferences/com.example.foo.helper.plist", bytes: 10)
        try sandbox.makeDirectory("Library/Caches/com.example.bar")

        let found = await finder.leftovers(
            for: app("Foo", "com.example.foo"),
            otherBundleIDs: ["com.example.foo.helper", "com.example.bar"])
        #expect(Set(found.map(\.url.lastPathComponent)) == ["com.example.foo"])
    }

    @Test func appleOrganizationPrefixIsNeverUsed() async throws {
        try sandbox.makeDirectory("Library/Caches/com.apple.Safari")
        let found = await finder.leftovers(for: app("Thing", "com.apple.thing"), otherBundleIDs: [])
        #expect(found.isEmpty)
    }

    @Test func appWithoutBundleIDHasNoLeftovers() async throws {
        try sandbox.makeDirectory("Library/Application Support/Foo")
        let found = await finder.leftovers(for: app("Foo", nil), otherBundleIDs: [])
        #expect(found.isEmpty)
    }

    @Test func onlyReturnsPathsInsideLibrary() async throws {
        try sandbox.makeDirectory("Library/Caches/com.example.foo")
        try sandbox.makeDirectory("com.example.foo")
        let found = await finder.leftovers(for: app("Foo", "com.example.foo"), otherBundleIDs: [])
        #expect(found.count == 1)
        #expect(found.allSatisfy { $0.url.path.hasPrefix(sandbox.library.path + "/") }, "\(found.map(\.url.path)) vs \(sandbox.library.path)")
    }

    @Test func shortAppNamesDoNotMatchByName() async throws {
        try sandbox.makeDirectory("Library/Application Support/Go")
        let found = await finder.leftovers(for: app("Go", "org.golang.go"), otherBundleIDs: [])
        #expect(found.isEmpty)
    }
}
