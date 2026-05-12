import SwiftUI

struct UpcomingEventCardView: View {
    let item: HangoutDisplayItem
    let photoRepository: ActivityPhotoRepository

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
                if isOngoing {
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
        .sheet(isPresented: $showingPhotoSheet) {
            if let activity = item.hangout.resolvedActivity {
                ReminderPhotoSheet(
                    activity: activity,
                    hangoutID: item.hangout.id,
                    existingPhotos: photoRepository.photos(for: activity).map { $0.imageData },
                    onSave: { data in
                        let photo = ActivityPhoto(activity: activity, hangoutID: item.hangout.id, imageData: data)
                        try? photoRepository.add(photo)
                        showingPhotoSheet = false
                    },
                    onDismiss: { showingPhotoSheet = false }
                )
            }
        }
    }

    private var activityLabel: String {
        item.hangout.resolvedActivity?.rawValue ?? item.hangout.activity
    }

    private var isOngoing: Bool {
        let now = Date.now
        return now >= item.hangout.startDate && now <= item.hangout.endDate
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
