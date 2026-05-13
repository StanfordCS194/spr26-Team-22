import SwiftUI
import AVFoundation

struct ReminderPhotoSheet: View {
    let activity: Activity
    let hangoutID: UUID?
    let existingPhotos: [Data]
    let onSave: (Data) -> Void
    let onDismiss: () -> Void

    @State private var showingCamera = false
    @State private var showingPermissionAlert = false

    private var existingPhoto: Data? { existingPhotos.first }

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
            .safeAreaInset(edge: .top) {
                Text("Snap a photo — we'll use it to nudge you next time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .sheet(isPresented: $showingCamera) {
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
            .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow camera access in Settings to capture photos.")
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        if let data = existingPhoto, let uiImage = UIImage(data: data) {
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
        if existingPhoto != nil {
            // Photo exists: let user choose to keep it or replace
            HStack(spacing: 12) {
                Button("Enjoy the moment", action: onDismiss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    requestCameraAccess()
                } label: {
                    Label("Replace photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Button {
                requestCameraAccess()
            } label: {
                Label("Capture this moment", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showingCamera = true }
                    else { showingPermissionAlert = true }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            showingCamera = true
        }
    }
}
