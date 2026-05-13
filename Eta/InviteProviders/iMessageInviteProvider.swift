import UIKit
import MessageUI

final class iMessageInviteProvider: NSObject, InviteProvider, MFMessageComposeViewControllerDelegate {
    
    func sendInvite(for suggestion: Suggestion) {
        guard let phone = suggestion.contact.phoneNumber else { return }
        
        guard MFMessageComposeViewController.canSendText() else {
            // Fallback for devices that can't send MMS (e.g. iPad without cellular).
            // Opens Messages via URL scheme without the .ics attachment.
            var components = URLComponents()
            components.scheme = "sms"
            components.path = phone
            components.queryItems = [URLQueryItem(name: "body", value: messageBody(for: suggestion))]
            if let url = components.url { UIApplication.shared.open(url) }
            return
        }
        
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.recipients = [phone]
        composer.body = messageBody(for: suggestion)

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
    
    private func messageBody(for suggestion: Suggestion) -> String {
        
        let activity = suggestion.activityDescription.prefix(1).lowercased()
        + suggestion.activityDescription.dropFirst()
        
        let options = suggestion.proposedTimes.prefix(3)
        
        let formattedOptions = options.enumerated().map { index, interval in
            let letter = ["A", "B", "C"][index]
            return "\(letter)) \(format(interval.start)) - \(format(interval.end))"
        }.joined(separator: "\n")
        
        return """
        Want to hang out?
        
        \(activity)
        
        Pick a time that works:
        
        \(formattedOptions)
        
        Reply with A, B, C, or (D to decline)
        """
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
