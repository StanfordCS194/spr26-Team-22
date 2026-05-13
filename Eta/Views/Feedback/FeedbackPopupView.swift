import SwiftUI

struct FeedbackPopupView: View {
    let hangoutID: UUID
    let invitationManager: InvitationManager

    @State private var friendRating: Int = 0
    @State private var activityThumbsUp: Bool?

    private var hangout: ScheduledHangout? {
        invitationManager.fetchHangout(id: hangoutID)
    }

    private var canSubmit: Bool {
        friendRating > 0 && activityThumbsUp != nil
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("How was it?")
                    .font(.title3.bold())
                if let hangout {
                    Text("\(hangout.activity) with \(hangout.contact?.name ?? "your friend")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("How was the company?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    FaceOption(symbol: "face.dashed", label: "Meh", isSelected: friendRating == 1) {
                        friendRating = 1
                    }
                    FaceOption(symbol: "face.smiling", label: "Good", isSelected: friendRating == 2) {
                        friendRating = 2
                    }
                    FaceOption(symbol: "face.smiling", label: "Great", isSelected: friendRating == 3, filled: true) {
                        friendRating = 3
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Would you do this again?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ThumbOption(symbol: "hand.thumbsdown", label: "Nah", isSelected: activityThumbsUp == false) {
                        activityThumbsUp = false
                    }
                    ThumbOption(symbol: "hand.thumbsup", label: "Yes", isSelected: activityThumbsUp == true) {
                        activityThumbsUp = true
                    }
                }
            }

            VStack(spacing: 8) {
                Button("Done") {
                    try? invitationManager.submitFeedback(
                        hangoutID: hangoutID,
                        friendRating: friendRating,
                        activityRating: activityThumbsUp == true ? 1 : 0
                    )
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!canSubmit)

                Button("Skip") {
                    invitationManager.dismissFeedback()
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }
}

private struct FaceOption: View {
    let symbol: String
    let label: String
    let isSelected: Bool
    var filled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: filled ? "\(symbol).fill" : symbol)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct ThumbOption: View {
    let symbol: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(symbol).fill" : symbol)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
