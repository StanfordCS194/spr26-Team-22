import SwiftUI

/// 2px bar pinned to the bottom of a row. Fill encodes recency via warmthBarColor.
/// Replaces the row divider — do not render a divider alongside this.
struct WarmthBar: View {
    let days: Int?

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(EtaColor.hairline)
            if let d = days {
                let w = EtaColor.warmth(Double(d))
                Rectangle()
                    .fill(EtaColor.warmthBarColor(d))
                    .scaleEffect(x: max(0.02, w), anchor: .leading)
            }
        }
        .frame(height: 2)
        .frame(maxWidth: .infinity)
    }
}
