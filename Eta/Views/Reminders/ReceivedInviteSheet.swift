import SwiftUI

struct ReceivedInviteSheet: View {
    let invite: RemoteInvitation
    let senderName: String
    let isEdit: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onDismissedWithoutResponse: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var responded = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text(isEdit ? "\(senderName) updated the event!" : "\(senderName) invited you!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(invite.activity)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(formattedTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button("Accept") { responded = true; onAccept() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .buttonStyle(.borderedProminent)

                Button("Decline") { responded = true; onDecline() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)

                Button("Answer Later") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onDisappear { if !responded { onDismissedWithoutResponse() } }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: invite.startTime)
    }
}
