import UIKit
import MessageUI

final class iMessageInviteProvider: NSObject, InviteProvider, MFMessageComposeViewControllerDelegate {
    
    func sendInvite(for suggestion: Suggestion, invitationID: String) {
        let recipient = suggestion.contact.phoneNumber ?? suggestion.contact.emailAddress
        guard let recipient else { return }

        let body = messageBody(for: suggestion, invitationID: invitationID)

        guard MFMessageComposeViewController.canSendText() else {
            var components = URLComponents()
            components.scheme = "sms"
            components.path = recipient
            components.queryItems = [URLQueryItem(name: "body", value: body)]
            if let url = components.url { UIApplication.shared.open(url) }
            return
        }

        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.recipients = [recipient]
        composer.body = body

        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow?
            .rootViewController
        else { return }

        rootVC.present(composer, animated: true)
    }
    
    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
    }
    
    // MARK: - Private
    
    private func messageBody(for suggestion: Suggestion, invitationID: String) -> String {
        let activity = suggestion.activityDescription.prefix(1).lowercased()
            + suggestion.activityDescription.dropFirst()

        let options = suggestion.proposedTimes.prefix(3)
        let formattedOptions = options.enumerated().map { index, interval in
            let letter = ["A", "B", "C"][index]
            return "\(letter)) \(format(interval.start)) - \(format(interval.end))"
        }.joined(separator: "\n")

        var body = """
        Want to hang out?

        \(activity)

        Pick a time that works:

        \(formattedOptions)

        Reply with A, B, C, or (D to decline)
        """

        if let rsvpURL = webRSVPURL(for: invitationID) {
            body += "\n\nOr RSVP here (no app needed):\n\(rsvpURL)"
        }

        return body
    }

    private func webRSVPURL(for invitationID: String) -> String? {
        let host = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? ""
        guard !host.isEmpty else { return nil }
        return "https://\(host)/functions/v1/invite-rsvp?id=\(invitationID)"
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
