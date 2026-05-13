import SwiftUI

struct SuggestionCard: View {
    let displayName: String
    let timeLabel: String
    let suggestion: Suggestion
    let onCustomize: () -> Void
    let latestPhotoData: Data?
    let onDismiss: () -> Void
    let onSchedule: () -> Void
    let analyticsService: AnalyticsService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("You have time \(timeLabel) —")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("want to \(activityPhrase) with \(displayName)?")
                    .font(.title)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let data = latestPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 20)
            }

            Spacer()

            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                Button("Yes, let's do it!") {
                    onSchedule()
                }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button("See details & edit") {
                    analyticsService.logButtonTapped(screen: "SuggestionCard", button: "SeeDetailsEdit")
                    onCustomize()
                }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Maybe Later") {
                    onDismiss()
                }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var activityPhrase: String {
        let raw = suggestion.activityDescription
        return raw.prefix(1).lowercased() + raw.dropFirst()
    }
}
