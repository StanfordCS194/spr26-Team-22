import SwiftUI

struct InsightCard: View {
    let insight: PersonalRelationshipInsight
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.title3)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
            }

            Text(insight.headline)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAction) {
                Text(actionLabel)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(iconColor)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var iconName: String {
        switch insight.type {
        case .drift:        return "arrow.trianglehead.turn.up.right.circle"
        case .reflection:   return "bubble.left"
        case .network:      return "person.3"
        case .pattern:      return "repeat"
        case .opportunity:  return "calendar.badge.checkmark"
        case .milestone:    return "star"
        }
    }

    private var iconColor: Color {
        switch insight.type {
        case .drift:        return .orange
        case .reflection:   return .blue
        case .network:      return .purple
        case .pattern:      return .teal
        case .opportunity:  return .green
        case .milestone:    return .pink
        }
    }

    private var actionLabel: String {
        switch insight.primaryAction {
        case .planActivity: return "Plan something"
        case .sendCheckIn:  return "Send a quick check-in"
        case .addGoal:      return "Add to goals"
        case .snooze:       return "Snooze"
        case .reflect:      return "Share how it went"
        }
    }
}

struct InsightCardEmptyState: View {
    let onAddFriends: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a few friends and Eta will start spotting patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Add friends", action: onAddFriends)
                .font(.subheadline.weight(.medium))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
