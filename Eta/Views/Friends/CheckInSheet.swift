import SwiftUI
import PhotosUI
import MessageUI

struct CheckInSheet: View {
    let displayName: String
    let givenName: String
    let phoneNumber: String
    let initialTemplate: String
    let onSend: (String, Bool) -> Void
    let onDismiss: () -> Void

    enum AttachmentMode: String, CaseIterable {
        case none  = "None"
        case photo = "Photo"
        case nudge = "Nudge"
    }

    @State private var messageText: String
    @State private var saveAsDefault = false
    @State private var attachmentMode: AttachmentMode = .none
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingComposer = false
    @State private var pendingAttachment: (data: Data, uti: String, filename: String)?
    @Environment(\.openURL) private var openURL

    init(
        displayName: String,
        givenName: String,
        phoneNumber: String,
        initialTemplate: String,
        onSend: @escaping (String, Bool) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.displayName = displayName
        self.givenName = givenName
        self.phoneNumber = phoneNumber
        self.initialTemplate = initialTemplate
        self.onSend = onSend
        self.onDismiss = onDismiss
        let personalized = initialTemplate.localizedCaseInsensitiveContains(givenName)
            ? initialTemplate
            : "Hey \(givenName)! \(initialTemplate)"
        _messageText = State(initialValue: personalized)
    }

    private var trimmed: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .lineLimit(4...)
                } header: {
                    Text("Message to \(displayName)")
                } footer: {
                    Text("Opens in Messages.")
                }

                Section("Attachment") {
                    Picker("", selection: $attachmentMode) {
                        ForEach(AttachmentMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if attachmentMode == .photo {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(
                                photoData != nil ? "Change photo" : "Choose photo",
                                systemImage: "photo"
                            )
                        }
                    }

                    if attachmentMode == .nudge {
                        NudgeCardPreview()
                            .frame(maxWidth: .infinity)
                            .listRowInsets(.init(top: 12, leading: 12, bottom: 12, trailing: 12))
                    }
                }

                Section {
                    Toggle("Save as my default check-in", isOn: $saveAsDefault)
                }
            }
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(trimmed.isEmpty || (attachmentMode == .photo && photoData == nil))
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                photoData = try? await newItem?.loadTransferable(type: Data.self)
            }
        }
        .sheet(isPresented: $showingComposer) {
            if let attachment = pendingAttachment {
                MessageComposerView(
                    recipient: phoneNumber,
                    body: trimmed,
                    attachmentData: attachment.data,
                    attachmentUTI: attachment.uti,
                    attachmentFilename: attachment.filename,
                    onFinish: {
                        showingComposer = false
                        onDismiss()
                    }
                )
            }
        }
    }

    // MARK: - Send

    private func send() {
        guard !trimmed.isEmpty else { return }
        onSend(trimmed, saveAsDefault)

        switch attachmentMode {
        case .none:
            sendViaURLScheme()

        case .photo:
            guard let data = photoData else { return }
            if MFMessageComposeViewController.canSendText() {
                pendingAttachment = (data, "public.jpeg", "photo.jpg")
                showingComposer = true
            } else {
                sendViaURLScheme()
            }

        case .nudge:
            if MFMessageComposeViewController.canSendText(),
               let data = renderNudgeCard() {
                pendingAttachment = (data, "public.jpeg", "nudge.jpg")
                showingComposer = true
            } else {
                sendViaURLScheme()
            }
        }
    }

    private func sendViaURLScheme() {
        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "sms:\(phoneNumber)&body=\(encoded)") {
            openURL(url)
        }
        onDismiss()
    }

    @MainActor
    private func renderNudgeCard() -> Data? {
        let renderer = ImageRenderer(content: NudgeCardView())
        renderer.scale = 3.0
        return renderer.uiImage?.jpegData(compressionQuality: 0.9)
    }
}

// MARK: - Nudge card

private struct NudgeCardView: View {
    private let etaTeal = Color(red: 0.25, green: 0.48, blue: 0.46)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(etaTeal)
                .frame(width: 260, height: 140)

            VStack(spacing: 10) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text("Thinking of you")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("sent with Eta")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

private struct NudgeCardPreview: View {
    var body: some View {
        HStack {
            Spacer()
            NudgeCardView()
                .scaleEffect(0.75)
                .frame(height: 105)
            Spacer()
        }
    }
}
