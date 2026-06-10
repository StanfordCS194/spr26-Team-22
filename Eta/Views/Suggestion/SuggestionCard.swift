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
    let daysSinceLastHangout: Int?
    let socialWarmth: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Lead line — name only in the question, not as a separate header
            VStack(alignment: .leading, spacing: 6) {
                Text("You have time \(timeLabel) —")
                    .font(.title2)
                    .foregroundStyle(EtaColor.text2)
                Text("want to \(activityPhrase) with \(displayName)?")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(EtaColor.text1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 12)

            // Warmth sliver under the lead line
            WarmthBar(days: daysSinceLastHangout)
                .padding(.bottom, 8)

            // Optional photo
            if let data = latestPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.top, 20)
            }

            Spacer()

            // Reason
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(EtaColor.text2)
                .padding(.bottom, 28)

            // Actions
            VStack(spacing: 10) {
                Button {
                    analyticsService.logSuggestionTapped(contactName: displayName)
                    analyticsService.logButtonTapped(screen: "SuggestionCard", button: "SuggestPlan")
                    onSchedule()
                } label: {
                    Text("Suggest plan")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(primaryButtonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(EtaColor.orbGradient(s: socialWarmth), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    analyticsService.logButtonTapped(screen: "SuggestionCard", button: "SeeDetailsEdit")
                    onCustomize()
                } label: {
                    Text("See details & edit")
                        .font(.body.weight(.medium))
                        .foregroundStyle(EtaColor.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    analyticsService.logButtonTapped(screen: "SuggestionCard", button: "NotNow")
                    onDismiss()
                } label: {
                    Text("Not now")
                        .foregroundStyle(EtaColor.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background {
            // Frosted glass card
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color(red: 16/255, green: 18/255, blue: 20/255).opacity(0.46))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var activityPhrase: String {
        let raw = suggestion.activityDescription
        return raw.prefix(1).lowercased() + raw.dropFirst()
    }

    // Spec: when anchor lightness > 56 (gold end of ramp), darken text so it doesn't wash out.
    private var primaryButtonTextColor: Color {
        socialWarmth > 0.85
            ? Color(red: 0.08, green: 0.14, blue: 0.04)
            : EtaColor.ink0
    }
}
