import SwiftUI

struct UpcomingEventCardView: View {
    let item: HangoutDisplayItem
    let photoRepository: ActivityPhotoRepository
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showingPhotoSheet = false

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
            VStack(alignment: .trailing, spacing: 8) {
                StatusBadgeView(status: item.hangout.status)
                if showsCameraButton {
                    Button { showingPhotoSheet = true } label: {
                        Image(systemName: "camera")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            if let onEdit {
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingPhotoSheet) {
            let activity = item.hangout.resolvedActivity ?? .walk
            let hangoutID = item.hangout.id
            ReminderPhotoSheet(
                activity: activity,
                hangoutID: hangoutID,
                existingPhotos: photoRepository.photos(for: hangoutID).map { $0.imageData },
                onSave: { data in
                    try? photoRepository.save(imageData: data, activity: activity, hangoutID: hangoutID)
                    showingPhotoSheet = false
                },
                onDismiss: { showingPhotoSheet = false }
            )
        }
    }

    private var activityLabel: String {
        item.hangout.resolvedActivity?.rawValue ?? item.hangout.activity
    }

    private var showsCameraButton: Bool {
        guard item.hangout.status == .confirmed else { return false }
        let cutoff = item.hangout.startDate.addingTimeInterval(24 * 60 * 60)
        return Date.now <= cutoff
    }

    private var hangoutHasPhoto: Bool {
        Activity.allCases.contains { activity in
            photoRepository.photos(for: activity).contains { $0.hangoutID == item.hangout.id }
        }
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
