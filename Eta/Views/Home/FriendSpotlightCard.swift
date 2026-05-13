import SwiftUI

struct FriendSpotlightCard: View {
    let item: FriendSpotlightItem
    let displayName: String

    var body: some View {
        HStack(spacing: 14) {
            initialsAvatar

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(item.contextLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 1)
    }

    private var initialsAvatar: some View {
        Text(initials)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(avatarColor, in: Circle())
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let index = abs(item.contact.id.hashValue) % colors.count
        return colors[index]
    }
}
