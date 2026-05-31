import SwiftUI
import MessageUI

/// Wraps MFMessageComposeViewController so CheckInSheet can send attachments.
struct MessageComposerView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    let attachmentData: Data
    let attachmentUTI: String
    let attachmentFilename: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = [recipient]
        vc.body = body
        vc.addAttachmentData(attachmentData, typeIdentifier: attachmentUTI, filename: attachmentFilename)
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onFinish()
        }
    }
}
