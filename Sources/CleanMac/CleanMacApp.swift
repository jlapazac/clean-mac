import AppKit
import SwiftUI

@main
struct CleanMacApp: App {
    init() {
        // When launched with `swift run` there is no bundle; make it a regular foreground app.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("CleanMac") {
            ContentView()
                .onAppear { NSApplication.shared.activate() }
        }
    }
}
