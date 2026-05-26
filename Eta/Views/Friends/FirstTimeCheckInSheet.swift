import SwiftUI

struct FirstTimeCheckInSheet: View {
    let displayName: String
    let phoneNumber: String
    let onSave: (String) -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void

    @State private var messageText = ""
    @Environment(\.openURL) private var openURL

    private var trimmed: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveMessage: String {
        trimmed.isEmpty ? "Hey \(displayName)! How have you been?" : trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Hey! How have you been?", text: $messageText, axis: .vertical)
                        .lineLimit(3...)
                } header: {
                    Text("What would you usually say?")
                } footer: {
                    Text("Saved as your default check-in message for all friends. You can always edit it before sending.")
                }
            }
            .navigationTitle("Set your check-in style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onSkip() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Send") { saveAndSend() }
                }
            }
        }
    }

    private func saveAndSend() {
        onSave(effectiveMessage)
        var components = URLComponents()
        components.scheme = "sms"
        components.path = phoneNumber
        components.queryItems = [URLQueryItem(name: "body", value: effectiveMessage)]
        if let url = components.url {
            openURL(url)
        }
    }
}
