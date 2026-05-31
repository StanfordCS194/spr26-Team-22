import SwiftUI

/// Shown at first launch when the Me contact has no phone or email.
/// Lets the user manually enter their identifier for remote invite routing.
struct PhoneSetupView: View {
    let phoneSetupService: PhoneSetupService
    let onComplete: () -> Void

    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("One quick thing")
                    .font(.largeTitle.bold())
                Text("Enter your phone number so friends can send you invites.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            TextField("Phone or email", text: $input)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            Button {
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                phoneSetupService.store(identifier: PhoneSetupService.normalized(trimmed))
                onComplete()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
    }
}
