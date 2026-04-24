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

        if let icsData = icsContent(for: suggestion).data(using: .utf8) {
            composer.addAttachmentData(icsData, typeIdentifier: "com.apple.ical.ics", filename: "hangout.ics")
        }

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
        let activity = suggestion.activity.rawValue.prefix(1).lowercased() + suggestion.activity.rawValue.dropFirst()
        return "Hey! Are you free \(timePhrase(for: suggestion.proposedTime.start))? Would you be down to \(activity)?"
    }

    /// Generates a valid iCalendar (.ics) string for the suggestion.
    /// Uses CRLF line endings per RFC 5545.
    private func icsContent(for suggestion: Suggestion) -> String {
        let firstName = suggestion.contact.givenName.isEmpty
            ? suggestion.contact.name
            : suggestion.contact.givenName
        let lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Eta//Eta//EN",
            "BEGIN:VEVENT",
            "UID:\(UUID().uuidString)@eta",
            "DTSTAMP:\(icsDate(.now))",
            "DTSTART:\(icsDate(suggestion.proposedTime.start))",
            "DTEND:\(icsDate(suggestion.proposedTime.end))",
            "SUMMARY:\(suggestion.activity.rawValue) with \(firstName)",
            "DESCRIPTION:\(suggestion.reason)",
            "END:VEVENT",
            "END:VCALENDAR"
        ]
        return lines.joined(separator: "\r\n")
    }

    private func icsDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.string(from: date)
    }

    private func timePhrase(for date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let slotDay = cal.startOfDay(for: date)
        let dayOffset = cal.dateComponents([.day], from: today, to: slotDay).day ?? 0
        let hour = cal.component(.hour, from: date)

        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<18: timeOfDay = "afternoon"
        default: timeOfDay = "evening"
        }

        switch dayOffset {
        case 0: return "this \(timeOfDay)"
        case 1: return "tomorrow \(timeOfDay)"
        default:
            let df = DateFormatter()
            df.dateFormat = "EEEE"
            return "\(df.string(from: date)) \(timeOfDay)"
        }
    }
}
