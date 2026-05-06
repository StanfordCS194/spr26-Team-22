import UIKit
import Messages
import SwiftUI

// MARK: - Data

private struct InviteActivity: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let color: Color

    static let all: [InviteActivity] = [
        InviteActivity(id: "walk", name: "Walk", icon: "figure.walk.motion", color: Color(red: 0.90, green: 0.46, blue: 0.44)),
        InviteActivity(id: "coffee", name: "Coffee", icon: "mug.fill", color: Color(red: 0.82, green: 0.63, blue: 0.32)),
        InviteActivity(id: "grocery", name: "Groceries", icon: "basket.fill", color: Color(red: 0.80, green: 0.50, blue: 0.36)),
        InviteActivity(id: "lunch", name: "Lunch", icon: "fork.knife", color: Color(red: 0.72, green: 0.42, blue: 0.55)),
        InviteActivity(id: "workout", name: "Workout", icon: "dumbbell.fill", color: Color(red: 0.45, green: 0.55, blue: 0.68)),
        InviteActivity(id: "study", name: "Study", icon: "text.book.closed.fill", color: Color(red: 0.48, green: 0.62, blue: 0.52)),
    ]
}

private enum InviteStatus: String {
    case pending, accepted, declined
}

private let etaTeal = Color(red: 0.25, green: 0.48, blue: 0.46)
private let etaTealUI = UIColor(red: 0.25, green: 0.48, blue: 0.46, alpha: 1.0)

// MARK: - View Controller

class MessagesViewController: MSMessagesAppViewController {

    private var selectedActivity: InviteActivity?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = .clear
    }

    override func willBecomeActive(with conversation: MSConversation) {
        presentUI(for: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        guard let conversation = activeConversation else { return }
        presentUI(for: conversation)
    }

    private func presentUI(for conversation: MSConversation) {
        removeAllChildViewControllers()

        if let message = conversation.selectedMessage, let url = message.url {
            presentInviteDetail(from: url, session: message.session, conversation: conversation)
            return
        }

        switch presentationStyle {
        case .compact:
            presentCompactPicker()
        case .expanded:
            presentExpandedCompose()
        @unknown default:
            presentCompactPicker()
        }
    }

    private func presentCompactPicker() {
        let view = CompactActivityPicker { [weak self] activity in
            self?.selectedActivity = activity
            self?.requestPresentationStyle(.expanded)
        }
        embed(UIHostingController(rootView: view))
    }

    private func presentExpandedCompose() {
        let activity = selectedActivity ?? InviteActivity.all[0]
        let view = ExpandedComposeView(
            initialActivity: activity,
            onSend: { [weak self] activity, date, note in
                self?.sendInvite(activity: activity, date: date, note: note)
            },
            onCancel: { [weak self] in
                self?.selectedActivity = nil
                self?.requestPresentationStyle(.compact)
            }
        )
        embed(UIHostingController(rootView: view))
    }

    private func presentInviteDetail(from url: URL, session: MSSession?, conversation: MSConversation) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return }

        let activityName = items.first { $0.name == "activity" }?.value ?? "Hang out"
        let iconName = items.first { $0.name == "icon" }?.value ?? "calendar"
        let timestamp = items.first { $0.name == "date" }?.value ?? ""
        let note = items.first { $0.name == "note" }?.value ?? ""
        let statusRaw = items.first { $0.name == "status" }?.value ?? "pending"
        let status = InviteStatus(rawValue: statusRaw) ?? .pending
        let date = Date(timeIntervalSince1970: Double(timestamp) ?? Date().timeIntervalSince1970)
        let color = InviteActivity.all.first { $0.name == activityName }?.color ?? etaTeal

        let view = EnvelopeDetailView(
            activityName: activityName, icon: iconName,
            date: date, note: note, status: status, accentColor: color
        ) { [weak self] newStatus in
            self?.respondToInvite(
                activityName: activityName, icon: iconName,
                date: date, note: note, status: newStatus,
                session: session, conversation: conversation
            )
        }
        embed(UIHostingController(rootView: view))
    }

    // MARK: - Sending

    private func sendInvite(activity: InviteActivity, date: Date, note: String) {
        guard let conversation = activeConversation else { return }

        let message = MSMessage(session: MSSession())
        let layout = MSMessageTemplateLayout()
        layout.image = renderEnvelopeCard(activity: activity, date: date, status: .pending)
        layout.caption = activity.name
        layout.subcaption = formatDate(date)

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "activity", value: activity.name),
            URLQueryItem(name: "date", value: "\(date.timeIntervalSince1970)"),
            URLQueryItem(name: "icon", value: activity.icon),
            URLQueryItem(name: "note", value: note),
            URLQueryItem(name: "status", value: InviteStatus.pending.rawValue),
        ]
        message.url = components.url
        message.layout = layout
        message.summaryText = "Hangout invite: \(activity.name)"

        conversation.insert(message) { [weak self] error in
            if error == nil {
                self?.selectedActivity = nil
                self?.requestPresentationStyle(.compact)
            }
        }
    }

    private func respondToInvite(
        activityName: String, icon: String, date: Date,
        note: String, status: InviteStatus,
        session: MSSession?, conversation: MSConversation
    ) {
        let message = MSMessage(session: session ?? MSSession())
        let layout = MSMessageTemplateLayout()

        let activity = InviteActivity.all.first { $0.name == activityName }
            ?? InviteActivity(id: "custom", name: activityName, icon: icon, color: etaTeal)
        layout.image = renderEnvelopeCard(activity: activity, date: date, status: status)

        switch status {
        case .accepted: layout.caption = "Accepted: \(activityName)"
        case .declined: layout.caption = "Can't make it"
        case .pending:  layout.caption = activityName
        }
        layout.subcaption = formatDate(date)

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "activity", value: activityName),
            URLQueryItem(name: "date", value: "\(date.timeIntervalSince1970)"),
            URLQueryItem(name: "icon", value: icon),
            URLQueryItem(name: "note", value: note),
            URLQueryItem(name: "status", value: status.rawValue),
        ]
        message.url = components.url
        message.layout = layout

        conversation.insert(message) { [weak self] error in
            if error == nil {
                self?.requestPresentationStyle(.compact)
            }
        }
    }

    // MARK: - Envelope Card Rendering

    private func renderEnvelopeCard(activity: InviteActivity, date: Date, status: InviteStatus) -> UIImage {
        let size = CGSize(width: 300, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let bounds = CGRect(origin: .zero, size: size)

            let bgColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
            bgColor.setFill()
            UIBezierPath(roundedRect: bounds, cornerRadius: 20).fill()

            let shimmer = UIColor.white.withAlphaComponent(0.6)
            shimmer.setFill()
            let shimmerRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.35)
            UIBezierPath(roundedRect: shimmerRect, cornerRadius: 20).fill()

            let sealCenter = CGPoint(x: size.width / 2, y: 70)
            let outerGlow = UIColor(red: 0.25, green: 0.48, blue: 0.46, alpha: 0.12)
            outerGlow.setFill()
            UIBezierPath(arcCenter: sealCenter, radius: 36, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()

            etaTealUI.setFill()
            UIBezierPath(arcCenter: sealCenter, radius: 28, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            let iconName: String = {
                switch status {
                case .pending:  return activity.icon
                case .accepted: return "checkmark"
                case .declined: return "xmark"
                }
            }()
            if let icon = UIImage(systemName: iconName, withConfiguration: symbolConfig)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let s = icon.size
                icon.draw(at: CGPoint(x: sealCenter.x - s.width / 2, y: sealCenter.y - s.height / 2))
            }

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1),
            ]
            let nameStr = activity.name as NSString
            let nameSize = nameStr.size(withAttributes: nameAttrs)
            nameStr.draw(at: CGPoint(x: (size.width - nameSize.width) / 2, y: 110), withAttributes: nameAttrs)

            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            let dateStr = formatDate(date) as NSString
            let dateSize = dateStr.size(withAttributes: dateAttrs)
            dateStr.draw(at: CGPoint(x: (size.width - dateSize.width) / 2, y: 134), withAttributes: dateAttrs)

            let (pillText, pillColor): (String, UIColor) = {
                switch status {
                case .pending:  return ("TAP TO OPEN", etaTealUI)
                case .accepted: return ("ACCEPTED ✓", .systemGreen)
                case .declined: return ("DECLINED", .systemGray)
                }
            }()
            let pillAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .heavy),
                .foregroundColor: pillColor,
            ]
            let pill = pillText as NSString
            let pillSize = pill.size(withAttributes: pillAttrs)
            let pillRect = CGRect(
                x: (size.width - pillSize.width) / 2 - 12, y: 162,
                width: pillSize.width + 24, height: pillSize.height + 12
            )
            pillColor.withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: pillRect, cornerRadius: (pillSize.height + 12) / 2).fill()
            pillColor.withAlphaComponent(0.3).setStroke()
            let pillBorder = UIBezierPath(roundedRect: pillRect, cornerRadius: (pillSize.height + 12) / 2)
            pillBorder.lineWidth = 0.5
            pillBorder.stroke()
            pill.draw(at: CGPoint(x: pillRect.minX + 12, y: pillRect.minY + 6), withAttributes: pillAttrs)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func embed(_ child: UIViewController) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    private func removeAllChildViewControllers() {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
}

// MARK: - Compact Picker

private struct CompactActivityPicker: View {
    let onSelect: (InviteActivity) -> Void

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(InviteActivity.all) { activity in
                Button { onSelect(activity) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: activity.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(activity.color)
                            .frame(width: 20)

                        Text(activity.name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .sensoryFeedback(.selection, trigger: activity.id)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Expanded Compose

private struct ExpandedComposeView: View {
    let initialActivity: InviteActivity
    let onSend: (InviteActivity, Date, String) -> Void
    let onCancel: () -> Void

    @State private var selectedActivity: InviteActivity
    @State private var selectedDate = Date()
    @State private var note = ""
    @State private var sendPressed = false
    @Namespace private var selectionNS

    init(initialActivity: InviteActivity,
         onSend: @escaping (InviteActivity, Date, String) -> Void,
         onCancel: @escaping () -> Void) {
        self.initialActivity = initialActivity
        self.onSend = onSend
        self.onCancel = onCancel
        _selectedActivity = State(initialValue: initialActivity)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Text("New Invite")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Activity", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(InviteActivity.all) { activity in
                            ActivityCard(
                                activity: activity,
                                isSelected: selectedActivity.id == activity.id,
                                namespace: selectionNS
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    selectedActivity = activity
                                }
                            }
                            .sensoryFeedback(.selection, trigger: selectedActivity.id)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("When", systemImage: "clock")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(etaTeal)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                            )
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Note", systemImage: "text.quote")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("e.g. Let's catch up!", text: $note)
                        .font(.system(size: 15))
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                                )
                        )
                }

                Button {
                    sendPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onSend(selectedActivity, selectedDate, note)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .symbolEffect(.bounce, value: sendPressed)
                        Text("Send Invite")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [selectedActivity.color, selectedActivity.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: selectedActivity.color.opacity(0.4), radius: 12, y: 5)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .sensoryFeedback(.impact(weight: .medium), trigger: sendPressed)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Activity Card

private struct ActivityCard: View {
    let activity: InviteActivity
    let isSelected: Bool
    var namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: activity.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                    .frame(height: 28)
                Text(activity.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(isSelected ? .white : .primary.opacity(0.8))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [activity.color, activity.color.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "selection", in: namespace)
                        .shadow(color: activity.color.opacity(0.35), radius: 10, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                        )
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Envelope Detail (Recipient)

private struct EnvelopeDetailView: View {
    let activityName: String
    let icon: String
    let date: Date
    let note: String
    let status: InviteStatus
    let accentColor: Color
    let onRespond: (InviteStatus) -> Void

    @State private var flapOpened = false
    @State private var cardRevealed = false
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                EnvelopeBody()

                if cardRevealed {
                    InviteCardContent(
                        activityName: activityName,
                        icon: icon,
                        date: date,
                        note: note,
                        accentColor: accentColor
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                        removal: .opacity
                    ))
                }

                EnvelopeFlap(opened: flapOpened)

                if !flapOpened {
                    WaxSeal(icon: icon, shimmer: shimmer)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture {
                guard !flapOpened else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    flapOpened = true
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.35)) {
                    cardRevealed = true
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: flapOpened)

            if !flapOpened {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 12))
                    Text("Tap to open")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .padding(.top, 24)
            }

            Spacer()

            if cardRevealed && status == .pending {
                ResponseButtons(accentColor: accentColor, onRespond: onRespond)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if status != .pending {
                StatusBanner(status: status)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if status != .pending {
                flapOpened = true
                cardRevealed = true
            } else {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    shimmer = true
                }
            }
        }
    }
}

// MARK: - Envelope Components

private struct EnvelopeBody: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .frame(width: 280, height: 210)
            .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

private struct EnvelopeFlap: View {
    let opened: Bool

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            path.closeSubpath()
            context.fill(path, with: .color(.white.opacity(0.6)))
            context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)
        }
        .frame(width: 280, height: 100)
        .offset(y: -55)
        .rotation3DEffect(
            .degrees(opened ? -180 : 0),
            axis: (x: 1, y: 0, z: 0),
            anchor: .top,
            perspective: 0.3
        )
        .opacity(opened ? 0 : 1)
    }
}

private struct WaxSeal: View {
    let icon: String
    let shimmer: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(etaTeal.opacity(shimmer ? 0.2 : 0.1))
                .frame(width: 60, height: 60)
                .scaleEffect(shimmer ? 1.1 : 1.0)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [etaTeal, etaTeal.opacity(0.7)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 24
                    )
                )
                .frame(width: 48, height: 48)
                .shadow(color: etaTeal.opacity(0.4), radius: 8, y: 3)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                )

            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .offset(y: -8)
    }
}

private struct InviteCardContent: View {
    let activityName: String
    let icon: String
    let date: Date
    let note: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Text(activityName)
                .font(.system(size: 20, weight: .bold, design: .rounded))

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text(formatDate(date))
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.secondary)

            if !note.isEmpty {
                Text("\"\(note)\"")
                    .font(.system(size: 14, design: .rounded))
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(width: 255)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

private struct ResponseButtons: View {
    let accentColor: Color
    let onRespond: (InviteStatus) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { onRespond(.declined) } label: {
                Text("Can't make it")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            Button { onRespond(.accepted) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("I'm in!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accentColor.opacity(0.35), radius: 10, y: 4)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

private struct StatusBanner: View {
    let status: InviteStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status == .accepted ? "checkmark.seal.fill" : "xmark.circle.fill")
                .foregroundStyle(status == .accepted ? .green : .secondary)
                .symbolEffect(.bounce, value: status == .accepted)
            Text(status == .accepted ? "You accepted this invite" : "You declined this invite")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Custom Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
