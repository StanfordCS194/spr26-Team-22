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
    var analyticsService: AnalyticsService?
    /// A photo of the contact to include in the nudge card, if available.
    var contactPhotoData: Data?

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
        onDismiss: @escaping () -> Void,
        analyticsService: AnalyticsService? = nil,
        contactPhotoData: Data? = nil
    ) {
        self.displayName = displayName
        self.givenName = givenName
        self.phoneNumber = phoneNumber
        self.initialTemplate = initialTemplate
        self.onSend = onSend
        self.onDismiss = onDismiss
        self.analyticsService = analyticsService
        self.contactPhotoData = contactPhotoData
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
                        NudgeCardPreview(photoData: contactPhotoData)
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
        .onChange(of: attachmentMode) { _, newMode in
            if newMode == .nudge { analyticsService?.logSendNudge(friendName: displayName) }
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
                        onSend(trimmed, saveAsDefault)
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

        switch attachmentMode {
        case .none:
            onSend(trimmed, saveAsDefault)
            sendViaURLScheme()

        case .photo:
            guard let data = photoData else { return }
            if MFMessageComposeViewController.canSendText() {
                pendingAttachment = (data, "public.jpeg", "photo.jpg")
                showingComposer = true
            } else {
                onSend(trimmed, saveAsDefault)
                sendViaURLScheme()
            }

        case .nudge:
            if MFMessageComposeViewController.canSendText(),
               let data = renderNudgeCard(photoData: contactPhotoData) {
                pendingAttachment = (data, "public.jpeg", "nudge.jpg")
                showingComposer = true
            } else {
                onSend(trimmed, saveAsDefault)
                sendViaURLScheme()
            }
        }
    }

    private func sendViaURLScheme() {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = phoneNumber
        components.queryItems = [URLQueryItem(name: "body", value: trimmed)]
        if let url = components.url {
            openURL(url)
        }
        onDismiss()
    }

    @MainActor
    private func renderNudgeCard(photoData: Data?) -> Data? {
        let renderer = ImageRenderer(content: NudgeCardView(photoData: photoData))
        renderer.scale = 3.0
        return renderer.uiImage?.jpegData(compressionQuality: 0.9)
    }
}

// MARK: - Nudge card

private struct NudgeCardView: View {
    var photoData: Data?
    private let etaTeal = Color(red: 0.25, green: 0.48, blue: 0.46)

    var body: some View {
        ZStack(alignment: .bottom) {
            if let data = photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 260, height: 160)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, etaTeal.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(etaTeal)
                    .frame(width: 260, height: 160)
            }

            VStack(spacing: 4) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Thinking of you")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("sent with Eta")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 16)
        }
        .frame(width: 260, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct NudgeCardPreview: View {
    var photoData: Data?

    var body: some View {
        HStack {
            Spacer()
            NudgeCardView(photoData: photoData)
                .scaleEffect(0.75)
                .frame(height: 120)
            Spacer()
        }
    }
}
