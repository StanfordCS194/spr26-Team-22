import SwiftUI

struct ReminderPhotoSheet: View {
    let activity: Activity
    let hangoutID: UUID?
    let existingPhotos: [Data]
    let onSave: (Data) -> Void
    let onDismiss: () -> Void

    @State private var showingCamera = false
    @State private var skipCapturePrompt = false
    @State private var displayedPhotoData: Data? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                photoSection
                captureSection
                Spacer()
            }
            .padding(24)
            .navigationTitle(activity.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(
                    onCapture: { image in
                        showingCamera = false
                        guard let data = image.thumbnail().jpegData80 else { return }
                        onSave(data)
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
            }
            .onAppear {
                displayedPhotoData = existingPhotos.randomElement()
                skipCapturePrompt = !existingPhotos.isEmpty && Int.random(in: 0..<5) == 0
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        if let data = displayedPhotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var captureSection: some View {
        if skipCapturePrompt {
            VStack(spacing: 12) {
                Text("Enjoy the moment!")
                    .font(.headline)
                Button("Take a photo anyway") { showingCamera = true }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                showingCamera = true
            } label: {
                Label(existingPhotos.isEmpty ? "Capture this moment" : "Add another photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
