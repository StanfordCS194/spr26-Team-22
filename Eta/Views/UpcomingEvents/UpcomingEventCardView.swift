import SwiftUI

struct UpcomingEventCardView: View {
    let item: HangoutDisplayItem

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activityLabel)
                    .font(.headline)
                Text("with \(item.contactName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(item.hangout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadgeView(status: item.hangout.status)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var activityLabel: String {
        item.hangout.resolvedActivity?.rawValue ?? item.hangout.activity
    }
}

private struct StatusBadgeView: View {
    let status: HangoutStatus

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .pending:   return "Pending"
        case .confirmed: return "Confirmed"
        case .canceled:  return "Canceled"
        }
    }

    private var color: Color {
        switch status {
        case .pending:   return .orange
        case .confirmed: return .green
        case .canceled:  return .red
        }
    }
}
