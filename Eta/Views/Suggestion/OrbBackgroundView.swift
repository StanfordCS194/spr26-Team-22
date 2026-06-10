import SwiftUI

/// Slowly drifting gradient orb field. Suggestions screen only.
/// Color tracks social temperature via socialWarmth (0=dormant, 1=active).
struct OrbBackgroundView: View {
    let socialWarmth: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var d0 = false  // main (36s)
    @State private var d1 = false  // aux  (42s)
    @State private var d2 = false  // top  (48s)
    @State private var d3 = false  // low  (52s)
    @State private var d4 = false  // spark(38s)
    @State private var breathe = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Main — center top, breathes
                orb(size: 340, blur: 6, opacity: 1.0)
                    .position(
                        x: w * 0.5 + (d0 ? 20 : -20),
                        y: 150      + (d0 ? 15 : -15)
                    )
                    .scaleEffect(breathe ? 1.07 : 0.93)

                // Aux — lower-left
                orb(size: 200, blur: 10, opacity: 0.50)
                    .position(
                        x: w * 0.18 + (d1 ? -14 : 14),
                        y: h  * 0.72 + (d1 ?  18 : -18)
                    )

                // Top — upper-right (partially off-screen)
                orb(size: 220, blur: 14, opacity: 0.40)
                    .position(
                        x: w         + (d2 ? -30 : -60),
                        y:             (d2 ?  80 :  40)
                    )

                // Low — bottom center (partially off-screen)
                orb(size: 260, blur: 16, opacity: 0.35)
                    .position(
                        x: w * 0.5   + (d3 ?  30 : -30),
                        y: h         + (d3 ? -60 : -100)
                    )

                // Spark — mid-right
                orb(size: 90, blur: 8, opacity: 0.45)
                    .position(
                        x: w * 0.85  + (d4 ?  8 : -8),
                        y: h * 0.45  + (d4 ? 12 : -12)
                    )
            }
        }
        .ignoresSafeArea()
        .onAppear { startAnimations() }
    }

    @ViewBuilder
    private func orb(size: CGFloat, blur: CGFloat, opacity: Double) -> some View {
        let core = EtaColor.orbAnchor(s: socialWarmth)
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: core,               location: 0.0),
                        .init(color: core.opacity(0.55), location: 0.6),
                        .init(color: core.opacity(0.0),  location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: blur)
            .opacity(opacity)
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 36).repeatForever(autoreverses: true)) { d0 = true }
        withAnimation(.linear(duration: 42).repeatForever(autoreverses: true)) { d1 = true }
        withAnimation(.linear(duration: 48).repeatForever(autoreverses: true)) { d2 = true }
        withAnimation(.linear(duration: 52).repeatForever(autoreverses: true)) { d3 = true }
        withAnimation(.linear(duration: 38).repeatForever(autoreverses: true)) { d4 = true }
        withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { breathe = true }
    }
}
