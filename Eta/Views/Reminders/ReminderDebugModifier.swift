import SwiftUI

struct ReminderDebugModifier: ViewModifier {
    let photoRepository: ActivityPhotoRepository
    let photoState: ReminderPhotoState

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomLeading) {
            content

            #if DEBUG
            Color.clear
                .frame(width: 80, height: 80)
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    triggerDebug()
                }
            #endif
        }
    }

    private func triggerDebug() {
        // Prefer the activity with the most photos; fall back to a random one.
        let best = Activity.allCases.max { a, b in
            photoRepository.photos(for: a).count < photoRepository.photos(for: b).count
        } ?? .walk
        let activity = photoRepository.photos(for: best).isEmpty
            ? (Activity.allCases.randomElement() ?? .walk)
            : best
        photoState.trigger(activity: activity)
    }
}

extension View {
    func reminderDebug(photoRepository: ActivityPhotoRepository, photoState: ReminderPhotoState) -> some View {
        modifier(ReminderDebugModifier(photoRepository: photoRepository, photoState: photoState))
    }
}
