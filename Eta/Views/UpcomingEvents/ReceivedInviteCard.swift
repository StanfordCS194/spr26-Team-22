import SwiftUI

struct ReceivedInviteCard: View {
    let invite: PendingReceivedInvitation
    let hasConflict: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.isEdit ? "\(invite.senderName) updated the event" : "\(invite.senderName) invited you")
                    .font(.headline)
                Text(invite.activity)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if hasConflict {
                    Label("You already have an event at this time", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 10) {
                Button("Decline", action: onDecline)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
                    .buttonStyle(.bordered)

                Button("Accept", action: onAccept)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(hasConflict)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: invite.startTime)
    }
}
