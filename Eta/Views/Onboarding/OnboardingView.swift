//
//  OnboardingView.swift
//  Eta
//

import SwiftUI
import Contacts

// MARK: - Step Enum

private enum OnboardingStep: Int, CaseIterable {
    case welcome    = 0
    case activities = 1
    case goals      = 2
    case contacts   = 3
    case done       = 4
}

// MARK: - Root

struct OnboardingView: View {
    var onFinish: (OnboardingPreferences) -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var preferences = OnboardingPreferences()
    @State private var animatingForward = true

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar (hidden on welcome)
                if step != .welcome {
                    OnboardingProgressBar(
                        current: step.rawValue,
                        total: OnboardingStep.allCases.count - 1  // exclude 'done'
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }

                // Step content
                ZStack {
                    switch step {
                    case .welcome:
                        WelcomeStep()
                    case .activities:
                        ActivitiesStep(selected: $preferences.favoriteActivities)
                    case .goals:
                        GoalsStep(frequency: $preferences.defaultFrequency)
                    case .contacts:
                        ContactsStep(selectedContacts: $preferences.selectedContacts)
                    case .done:
                        DoneStep(preferences: preferences)
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: animatingForward ? .trailing : .leading).combined(with: .opacity),
                        removal:   .move(edge: animatingForward ? .leading  : .trailing).combined(with: .opacity)
                    )
                )
                .id(step)

                // Navigation
                OnboardingNavBar(
                    step: step,
                    canAdvance: canAdvance,
                    onBack: goBack,
                    onNext: goNext
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Navigation

    private var canAdvance: Bool {
        switch step {
        case .welcome:    return true
        case .activities: return !preferences.favoriteActivities.isEmpty
        case .goals:      return true
        case .contacts:   return !preferences.selectedContacts.isEmpty
        case .done:       return true
        }
    }

    private func goNext() {
        if step == .done {
            onFinish(preferences)
            return
        }
        animatingForward = true
        withAnimation(.easeInOut(duration: 0.35)) {
            step = OnboardingStep(rawValue: step.rawValue + 1) ?? .done
        }
    }

    private func goBack() {
        guard step.rawValue > 1 else { return } // can't go back past activities
        animatingForward = false
        withAnimation(.easeInOut(duration: 0.35)) {
            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
        }
    }
}

// MARK: - Progress Bar

private struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    private var progress: Double {
        Double(current) / Double(total - 1)  // welcome=0, done excluded
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 4)
                Capsule()
                    .fill(Color.blue)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.easeInOut, value: current)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Nav Bar

private struct OnboardingNavBar: View {
    let step: OnboardingStep
    let canAdvance: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    private var nextLabel: String {
        switch step {
        case .welcome:    return "Get Started"
        case .activities: return "Next"
        case .goals:      return "Next"
        case .contacts:   return "Next"
        case .done:       return "Let's Go"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if step.rawValue > 1 && step != .done {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.primary)
                }
            }

            Button(action: onNext) {
                Text(nextLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canAdvance ? Color.blue : Color.blue.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canAdvance)
            .animation(.easeInOut, value: canAdvance)
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    private let features: [(icon: String, color: Color, title: String, desc: String)] = [
        ("person.2.fill",        .blue,   "Track Your People",    "Add friends and family you want to stay close with."),
        ("lightbulb.fill",       .orange, "Smart Suggestions",    "Get nudges when it's been a while — personalized to you."),
        ("calendar.badge.plus",  .green,  "Schedule Hangouts",    "Turn a suggestion into a plan and send the invite in seconds."),
    ]

    @State private var featurePage = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("👋").font(.system(size: 60)).padding(.top, 48)
                Text("Welcome to Eta")
                    .font(.largeTitle.bold())
                Text("Stay close to the people who matter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)

            TabView(selection: $featurePage) {
                ForEach(features.indices, id: \.self) { i in
                    let f = features[i]
                    VStack(spacing: 18) {
                        ZStack {
                            Circle().fill(f.color.opacity(0.12)).frame(width: 80, height: 80)
                            Image(systemName: f.icon).font(.system(size: 32)).foregroundStyle(f.color)
                        }
                        VStack(spacing: 6) {
                            Text(f.title).font(.title2.bold())
                            Text(f.desc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 40)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 240)

            HStack(spacing: 7) {
                ForEach(features.indices, id: \.self) { i in
                    Circle()
                        .fill(i == featurePage ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut, value: featurePage)
                }
            }
            .padding(.top, 20)

            Spacer()
        }
    }
}

// MARK: - Step 2: Activities

private struct ActivitiesStep: View {
    @Binding var selected: Set<ActivityType>

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                icon: "heart.fill",
                iconColor: .pink,
                title: "What do you like to do?",
                subtitle: "Eta will suggest hangouts that match your vibe. Pick everything that fits."
            )

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ActivityType.allCases) { activity in
                    ActivityTile(
                        activity: activity,
                        isSelected: selected.contains(activity)
                    ) {
                        if selected.contains(activity) {
                            selected.remove(activity)
                        } else {
                            selected.insert(activity)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            if selected.isEmpty {
                Text("Pick at least one to continue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }

            Spacer()
        }
    }
}

private struct ActivityTile: View {
    let activity: ActivityType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? activity.color : activity.color.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: activity.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? .white : activity.color)
                }
                Text(activity.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? activity.color.opacity(0.08) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? activity.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Step 3: Goals

private struct GoalsStep: View {
    @Binding var frequency: HangoutFrequency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                icon: "target",
                iconColor: .orange,
                title: "How often do you want to hang out?",
                subtitle: "Set your default rhythm. You can adjust this per person later."
            )

            VStack(spacing: 12) {
                ForEach(HangoutFrequency.allCases) { freq in
                    FrequencyRow(
                        frequency: freq,
                        isSelected: frequency == freq,
                        onTap: { frequency = freq }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

private struct FrequencyRow: View {
    let frequency: HangoutFrequency
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.orange : Color.orange.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: frequency.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? .white : .orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(frequency.rawValue).font(.headline)
                    Text(frequency.subtitle).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.orange.opacity(0.06) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Step 4: Contacts

private struct ContactsStep: View {
    @Binding var selectedContacts: [OnboardingContact]

    @State private var allContacts: [OnboardingContact] = []
    @State private var searchText = ""
    @State private var authStatus: CNAuthorizationStatus = .notDetermined
    @State private var isLoading = true

    private var filtered: [OnboardingContact] {
        guard !searchText.isEmpty else { return allContacts }
        return allContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            ($0.phoneNumber ?? "").contains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                icon: "person.2.fill",
                iconColor: .blue,
                title: "Who do you want to stay close with?",
                subtitle: "Add friends and family you'd like Eta to help you nurture."
            )

            switch authStatus {
            case .authorized:
                contactsList
            case .denied, .restricted:
                ContactsAccessDenied()
            default:
                ContactsPermissionPrompt {
                    requestAccess()
                }
            }
        }
        .onAppear {
            authStatus = CNContactStore.authorizationStatus(for: .contacts)
            if authStatus == .authorized { fetchContacts() }
            else { isLoading = false }
        }
    }

    private var contactsList: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search contacts", text: $searchText)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Selected chips
            if !selectedContacts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedContacts) { contact in
                            SelectedContactChip(contact: contact) {
                                selectedContacts.removeAll { $0.id == contact.id }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 36)
                .padding(.bottom, 10)
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { contact in
                            let isSelected = selectedContacts.contains { $0.id == contact.id }
                            ContactRow(contact: contact, isSelected: isSelected) {
                                if isSelected {
                                    selectedContacts.removeAll { $0.id == contact.id }
                                } else {
                                    selectedContacts.append(contact)
                                }
                            }
                            Divider().padding(.leading, 68)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func requestAccess() {
        CNContactStore().requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                authStatus = granted ? .authorized : .denied
                if granted { fetchContacts() }
            }
        }
    }

    private func fetchContacts() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let store = CNContactStore()
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .givenName

            var contacts: [OnboardingContact] = []
            try? store.enumerateContacts(with: request) { cn, _ in
                guard !cn.givenName.isEmpty || !cn.familyName.isEmpty else { return }
                contacts.append(OnboardingContact(
                    id: cn.identifier,
                    givenName: cn.givenName,
                    familyName: cn.familyName,
                    phoneNumber: cn.phoneNumbers.first?.value.stringValue
                ))
            }

            DispatchQueue.main.async {
                allContacts = contacts
                isLoading = false
            }
        }
    }
}

private struct ContactRow: View {
    let contact: OnboardingContact
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isSelected ? Color.blue : Color.blue.opacity(0.1)).frame(width: 44, height: 44)
                    Text(contact.initials)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName).font(.body)
                    if let phone = contact.phoneNumber {
                        Text(phone).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.4))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct SelectedContactChip: View {
    let contact: OnboardingContact
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(contact.givenName).font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.12))
        .foregroundStyle(Color.blue)
        .clipShape(Capsule())
    }
}

private struct ContactsPermissionPrompt: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
            Text("Access Your Contacts")
                .font(.title2.bold())
            Text("Eta needs contacts access to help you find friends to add.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Allow Contacts Access", action: onRequest)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 20)
    }
}

private struct ContactsAccessDenied: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Contacts access is disabled").font(.headline)
            Text("Enable it in Settings → Privacy → Contacts to add friends here, or skip and add them manually later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 20)
    }
}

// MARK: - Step 5: Done

private struct DoneStep: View {
    let preferences: OnboardingPreferences

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("🎉").font(.system(size: 72))

                Text("You're all set!")
                    .font(.largeTitle.bold())

                Text("Eta is ready. Here's what we've set up:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                SummaryRow(
                    icon: "heart.fill",
                    color: .pink,
                    text: preferences.favoriteActivities.isEmpty
                        ? "Activities saved"
                        : "\(preferences.favoriteActivities.count) activities you enjoy"
                )
                SummaryRow(
                    icon: "calendar",
                    color: .orange,
                    text: "Suggested hangouts \(preferences.defaultFrequency.rawValue.lowercased())"
                )
                SummaryRow(
                    icon: "person.2.fill",
                    color: .blue,
                    text: "\(preferences.selectedContacts.count) friend\(preferences.selectedContacts.count == 1 ? "" : "s") added"
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)

            Spacer()
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            }
            Text(text).font(.body)
            Spacer()
            Image(systemName: "checkmark").foregroundStyle(.green).fontWeight(.semibold)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shared Header

private struct StepHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle().fill(iconColor.opacity(0.12)).frame(width: 52, height: 52)
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(iconColor)
            }
            .padding(.bottom, 4)

            Text(title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}