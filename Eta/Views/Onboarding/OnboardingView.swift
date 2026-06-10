import SwiftUI
import UserNotifications

private let etaTeal = Color(red: 0.25, green: 0.48, blue: 0.46)

struct OnboardingView: View {
    @State private var currentPage = 0
    let viewModel: OnboardingViewModel
    var analyticsService: AnalyticsService?
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.98),
                    Color(red: 0.92, green: 0.95, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? etaTeal : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 32 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
                
                TabView(selection: $currentPage) {
                    OnboardingPageWelcome()
                        .tag(0)
                    
                    OnboardingPageFeatures()
                        .tag(1)
                    
                    OnboardingPagePreferences(viewModel: viewModel, analyticsService: analyticsService)
                        .tag(2)
                    
                    OnboardingPageGetStarted()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button(action: { withAnimation { currentPage -= 1 } }) {
                            Text("Back")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .foregroundColor(etaTeal)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(etaTeal.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    
                    if currentPage < 3 {
                        Button(action: { withAnimation { currentPage += 1 } }) {
                            Text("Next")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(etaTeal)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            Task {
                                let requestedAt = Date()
                                analyticsService?.logPermissionRequested(type: "Notifications")
                                do {
                                    let granted = try await UNUserNotificationCenter.current()
                                        .requestAuthorization(options: [.alert, .sound, .badge])
                                    let elapsed = Date().timeIntervalSince(requestedAt)
                                    if granted {
                                        analyticsService?.logPermissionGranted(type: "Notifications", timeElapsed: elapsed)
                                    } else {
                                        analyticsService?.logPermissionDenied(type: "Notifications", timeElapsed: elapsed)
                                    }
                                } catch {
                                    analyticsService?.logPermissionDenied(type: "Notifications", timeElapsed: Date().timeIntervalSince(requestedAt))
                                }
                            }
                            viewModel.completeOnboarding()
                        }) {
                            Text("Get Started")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(etaTeal)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

struct OnboardingPageWelcome: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)

            VStack(spacing: 8) {
                Text("Eta")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .tracking(0.5)

                Text("Nurture the friendships\nthat matter most")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                WelcomeFeatureRow(icon: "heart.fill", color: .pink, text: "Maintain meaningful friendships")
                WelcomeFeatureRow(icon: "clock.badge.checkmark", color: .blue, text: "Find the perfect time to connect")
                WelcomeFeatureRow(icon: "sparkles", color: .orange, text: "Smart suggestions just for you")
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct WelcomeFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary.opacity(0.75))

            Spacer()
        }
    }
}

struct OnboardingPageFeatures: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            
            Text("How It Works")
                .font(.system(size: 28, weight: .bold))
            
            VStack(spacing: 16) {
                FeatureCard(
                    icon: "clock.badge.checkmark",
                    iconColor: .blue,
                    title: "Availability Planning",
                    description: "Add times when you're free, and Eta will suggest hangouts that fit"
                )
                
                FeatureCard(
                    icon: "person.2",
                    iconColor: .purple,
                    title: "Track Your Friends",
                    description: "Add friends you want to stay connected with"
                )
                
                FeatureCard(
                    icon: "lightbulb.fill",
                    iconColor: .orange,
                    title: "Get Suggestions",
                    description: "Receive personalized hangout suggestions at the perfect time"
                )
                
                FeatureCard(
                    icon: "paperplane.fill",
                    iconColor: .pink,
                    title: "Send Invites",
                    description: "One tap to send a message with your suggested activity"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(12)
    }
}

struct OnboardingPageGetStarted: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            
            Text("You're All Set!")
                .font(.system(size: 28, weight: .bold))
            
            VStack(spacing: 16) {
                PermissionInfo(
                    icon: "clock.badge.checkmark",
                    iconColor: .blue,
                    title: "Availability",
                    description: "Tell Eta when you're free so suggestions only appear at useful times"
                )
                
                PermissionInfo(
                    icon: "person.crop.circle",
                    iconColor: .green,
                    title: "Contacts Access",
                    description: "Find and add friends you want to stay connected with"
                )
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    Text("All data stays on your device")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    Text("No backend or account needed")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    Text("Your privacy is our priority")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.black.opacity(0.7))
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Let's get started building better friendships!")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct PermissionInfo: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.6))
        .cornerRadius(10)
    }
}

struct OnboardingPagePreferences: View {
    let viewModel: OnboardingViewModel
    var analyticsService: AnalyticsService?
    @State private var enableNotifications: Bool = false
    @State private var notificationTime: Date = {
        var components = DateComponents()
        components.hour = 10
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var preferredActivities: [String] = []
    @State private var cityText: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            
            Text("Your Preferences")
                .font(.system(size: 28, weight: .bold))
            
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Location")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black.opacity(0.9))

                        CitySearchField(city: $cityText, onCommit: { value in
                            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.userPreferences.userCity = trimmed.isEmpty ? nil : trimmed
                            if !trimmed.isEmpty { analyticsService?.logUserLocationSet() }
                        })
                        .onChange(of: cityText) { _, value in
                            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.userPreferences.userCity = trimmed.isEmpty ? nil : trimmed
                        }

                        Text("Used to suggest in-person vs. online hangouts.")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorite Activities")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black.opacity(0.9))
                        
                        VStack(spacing: 10) {
                            ForEach(Activity.allCases, id: \.self) { activity in
                                ActivityToggle(
                                    activity: activity,
                                    isSelected: preferredActivities.contains(activity.rawValue),
                                    onChange: { isSelected in
                                        if isSelected {
                                            if !preferredActivities.contains(activity.rawValue) {
                                                preferredActivities.append(activity.rawValue)
                                            }
                                        } else {
                                            preferredActivities.removeAll { $0 == activity.rawValue }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Enable Notifications")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black.opacity(0.9))
                            
                            Spacer()
                            
                            Toggle("", isOn: $enableNotifications)
                                .tint(etaTeal)
                        }
                        
                        if enableNotifications {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Suggestion Time")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black.opacity(0.7))
                                
                                DatePicker(
                                    "Time",
                                    selection: $notificationTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .tint(etaTeal)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            enableNotifications = viewModel.userPreferences.enableNotifications
            notificationTime = viewModel.userPreferences.notificationTime
            preferredActivities = viewModel.userPreferences.preferredActivities
            cityText = viewModel.userPreferences.userCity ?? ""
        }
        .onChange(of: enableNotifications) { _, newValue in
            viewModel.userPreferences.enableNotifications = newValue
        }
        .onChange(of: notificationTime) { _, newValue in
            viewModel.userPreferences.notificationTime = newValue
        }
        .onChange(of: preferredActivities) { _, newValue in
            viewModel.userPreferences.preferredActivities = newValue
        }
    }
}

struct ActivityToggle: View {
    let activity: Activity
    let isSelected: Bool
    let onChange: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? etaTeal : .gray.opacity(0.5))
            
            Text(activity.rawValue)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
        .padding(12)
        .background(isSelected ? etaTeal.opacity(0.08) : Color.clear)
        .cornerRadius(8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                onChange(!isSelected)
            }
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(preferencesService: PreferencesService()))
}
