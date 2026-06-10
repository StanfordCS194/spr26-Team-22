import SwiftUI

enum EtaColor {
    // Backgrounds
    static let ink0     = Color.black
    static let ink1     = Color(red: 10/255,  green: 10/255,  blue: 10/255)
    static let surface1 = Color(red: 22/255,  green: 22/255,  blue: 24/255)
    static let surface2 = Color(red: 28/255,  green: 28/255,  blue: 30/255)
    static let hairline = Color(red: 32/255,  green: 32/255,  blue: 34/255)

    // Text
    static let text1 = Color.white
    static let text2 = Color(red: 122/255, green: 122/255, blue: 126/255)
    static let text3 = Color(red: 90/255,  green: 90/255,  blue: 94/255)

    // Warmth palette — the ONLY saturated color in the app
    // hsl(150, 62%, 52%) ≈ #34d36e
    static let warm = Color(red: 52/255, green: 211/255, blue: 110/255)
    // hsl(178, 62%, 52%) ≈ #34c9d3
    static let cool = Color(red: 52/255, green: 201/255, blue: 211/255)

    // Signature gradient — 135° warm top-left → cool bottom-right
    static let appGradient = LinearGradient(
        colors: [warm, cool],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Warmth functions

    /// 0..1 warmth score (1 = very recent, 0 = dormant). Steeper log scale for stark contrast.
    static func warmth(_ days: Double) -> Double {
        max(0, min(1, 1 - log10(days + 1) / 2.5))
    }

    /// Color for warmth bars: hue, saturation, and lightness all vary so
    /// healthy bars are vivid bright green and dormant bars are dim dull teal.
    static func warmthBarColor(_ days: Int) -> Color {
        let w = warmth(Double(days))
        let h = 150 + (1 - w) * 28   // green → teal
        let s = 0.50 + w * 0.22       // 50% sat (cold) → 72% sat (warm)
        let l = 0.36 + w * 0.20       // 36% lightness (cold) → 56% lightness (warm)
        return hsl(h: h, s: s, l: l)
    }

    /// Convert HSL (h in degrees, s and l in 0..1) to SwiftUI Color.
    static func hsl(h: Double, s: Double, l: Double) -> Color {
        let chroma = (1 - abs(2 * l - 1)) * s
        let v      = l + chroma / 2
        let sv     = v == 0 ? 0.0 : chroma / v
        return Color(hue: h / 360, saturation: sv, brightness: v)
    }
}

// MARK: - Social-temperature anchor (Suggestions screen only)

extension EtaColor {
    // Temperature ramp stops: (socialWarmth S, hue°, saturation, lightness)
    private static let tempStops: [(s: Double, h: Double, sat: Double, lit: Double)] = [
        (1.00, 46,  0.78, 0.60),  // warm gold
        (0.72, 150, 0.62, 0.52),  // brand emerald
        (0.48, 178, 0.62, 0.52),  // brand teal
        (0.24, 200, 0.58, 0.56),  // sky
        (0.00, 232, 0.48, 0.62)   // soft periwinkle
    ]

    /// Core anchor color interpolated from the social-warmth score (0..1).
    static func orbAnchor(s: Double) -> Color {
        let (h, sat, lit) = interpolatedHSL(s: s)
        return hsl(h: h, s: sat, l: lit)
    }

    /// Gradient for the primary button on the Suggestions screen (tracks temperature).
    static func orbGradient(s: Double) -> LinearGradient {
        let (h, sat, lit) = interpolatedHSL(s: s)
        let core = hsl(h: h,      s: sat,           l: lit)
        let edge = hsl(h: h + 22, s: max(0, sat - 0.06), l: max(0, lit - 0.10))
        return LinearGradient(colors: [core, edge], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private static func interpolatedHSL(s: Double) -> (h: Double, sat: Double, lit: Double) {
        let stops = tempStops
        for i in 0..<(stops.count - 1) {
            let hi = stops[i], lo = stops[i + 1]
            guard s >= lo.s else { continue }
            let t = (s - lo.s) / (hi.s - lo.s)
            return (
                lo.h   + t * (hi.h   - lo.h),
                lo.sat + t * (hi.sat - lo.sat),
                lo.lit + t * (hi.lit - lo.lit)
            )
        }
        let last = stops.last!
        return (last.h, last.sat, last.lit)
    }
}
