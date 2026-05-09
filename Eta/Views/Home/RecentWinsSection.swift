import SwiftUI

struct RecentWinsSection: View {
    let wins: [RecentWinItem]
    let onDismiss: (RecentWinItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Wins")
                .font(.title3.weight(.semibold))

            ForEach(wins) { win in
                RecentWinCard(win: win, onDismiss: { onDismiss(win) })
            }
        }
    }
}

private struct RecentWinCard: View {
    let win: RecentWinItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)

            Text(win.contextLine)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Color.secondary.opacity(0.1), in: Circle())
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}
