import SwiftUI

struct ActivityNudgeView: View {
    let activity: Activity
    let photoData: Data?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let data = photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: activityIcon)
                            .font(.system(size: 72))
                            .foregroundStyle(.secondary)
                        Text(activity.rawValue)
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Time to do this again soon?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(activity.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private var activityIcon: String {
        switch activity {
        case .walk:         return "figure.walk"
        case .coffee:       return "cup.and.saucer"
        case .groceryRun:   return "cart"
        case .lunch:        return "fork.knife"
        case .workout:      return "figure.run"
        case .studySession: return "book"
        }
    }
}
