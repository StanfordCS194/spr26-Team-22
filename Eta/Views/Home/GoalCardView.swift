import SwiftUI

struct GoalCardView: View {
    let goal: Goal
    let friendNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                progressRing
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(progressLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !friendNames.isEmpty {
                Text(friendNames.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(statusColor)
                Spacer()
                if goal.daysRemaining > 0 {
                    Text("\(goal.daysRemaining)d left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 190)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    // MARK: - Subviews

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: goal.progressFraction)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: goal.progressFraction)
            Text("\(goal.progress)/\(goal.target)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 40, height: 40)
    }

    // MARK: - Helpers

    private var progressLabel: String {
        "\(goal.progress) of \(goal.target) this \(goal.cadence.displayName)"
    }

    private var statusColor: Color {
        switch goal.status {
        case .onTrack:  return Color(red: 0.2, green: 0.7,  blue: 0.45)
        case .atRisk:   return Color(red: 0.9, green: 0.65, blue: 0.1)
        case .behind:   return Color(red: 0.85, green: 0.35, blue: 0.28)
        case .achieved: return Color(red: 0.3, green: 0.55, blue: 0.9)
        }
    }

    private var statusLabel: String {
        switch goal.status {
        case .onTrack:  return "On track"
        case .atRisk:   return "At risk"
        case .behind:   return "Behind"
        case .achieved: return "Achieved"
        }
    }
}
