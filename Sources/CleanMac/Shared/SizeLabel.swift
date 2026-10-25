import CleanMacCore
import SwiftUI

struct SizeLabel: View {
    let bytes: Int64

    var body: some View {
        Text(ByteFormatting.string(bytes))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

/// A horizontal bar showing `fraction` of the available width.
struct SizeBar: View {
    let fraction: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(tint)
                    .frame(width: max(2, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
    }
}
