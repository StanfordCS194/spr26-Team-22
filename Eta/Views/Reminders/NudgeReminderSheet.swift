import SwiftUI

struct NudgeReminderSheet: View {
    let contact: TrackedContact?
    let friendName: String?
    let activityRawValue: String
    let photoRepository: ActivityPhotoRepository
    let nudgeScheduler: NudgeScheduler
    let onScheduleNow: (Suggestion) -> Void
    let onSuggestions: () -> Void
    let onDismiss: () -> Void

    @State private var showNoSlot = false

    var body: some View {
        VStack(spacing: 0) {
            if let data = photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()
            }

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    Text(activityRawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }

                if showNoSlot {
                    Text("No free slot found in the next few days.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    if showNoSlot {
                        Button("View suggestions", action: onSuggestions)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Schedule it now") {
                            Task { @MainActor in
                                if let contact,
                                   let suggestion = await nudgeScheduler.buildSuggestion(
                                    contact: contact, activityRawValue: activityRawValue) {
                                    onScheduleNow(suggestion)
                                } else {
                                    showNoSlot = true
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .buttonStyle(.borderedProminent)
                        .disabled(contact == nil)

                        Button("View suggestions", action: onSuggestions)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.primary)
                            .buttonStyle(.plain)
                    }

                    Button("Maybe later", action: onDismiss)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var photoData: Data? {
        let activity = Activity(rawValue: activityRawValue) ?? .walk
        if let id = contact?.id {
            return photoRepository.photos(forContactID: id)
                .first { $0.activityRawValue == activityRawValue }?.imageData
                ?? photoRepository.photos(forContactID: id).first?.imageData
                ?? photoRepository.photos(for: activity).first?.imageData
        }
        return photoRepository.photos(for: activity).first?.imageData
    }

    private var friendHasPhoto: Bool {
        guard let id = contact?.id else { return false }
        return !photoRepository.photos(forContactID: id).isEmpty
    }

    private var title: String {
        friendName.map { "Time to catch up with \($0)" } ?? activityRawValue
    }

    private var subtitle: String {
        if let name = friendName {
            return friendHasPhoto
                ? "You had a great time together — why not do it again?"
                : "It's been a while since you caught up with \(name)."
        }
        return "Why not reach out to a friend today?"
    }
}
