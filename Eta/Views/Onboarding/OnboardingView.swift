import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    let viewModel: OnboardingViewModel
    
    var body: some View {
        ZStack {
            // Gradient background
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
                // Page indicator
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 32 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
                
                // Page content
                TabView(selection: $currentPage) {
                    OnboardingPageWelcome()
                        .tag(0)
                    
                    OnboardingPageFeatures()
                        .tag(1)
                    
                    OnboardingPagePreferences(viewModel: viewModel)
                        .tag(2)
                    
                    OnboardingPageGetStarted()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                // Navigation buttons
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button(action: { withAnimation { currentPage -= 1 } }) {
                            Text("Back")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .foregroundColor(.accentColor)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    
                    if currentPage < 3 {
                        Button(action: { withAnimation { currentPage += 1 } }) {
                            Text("Next")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: { viewModel.completeOnboarding() }) {
                            Text("Get Started")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
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
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.1),
                                Color.accentColor.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 12) {
                Text("Welcome to Eta")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(0.3)
                
                Text("Your friendship companion")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    
                    Text("Maintain meaningful friendships")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    
                    Text("Find the perfect time to connect")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    
                    Text("Smart suggestions just for you")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.black.opacity(0.7))
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.6))
            .cornerRadius(16)
            
            Spacer()
        }
        .padding(.horizontal, 24)
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
                    icon: "calendar",
                    iconColor: .blue,
                    title: "Smart Calendar Analysis",
                    description: "Eta reads your calendar to find free slots in your schedule"
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
                    icon: "calendar",
                    iconColor: .blue,
                    title: "Calendar Access",
                    description: "We'll analyze your calendar to find free time"
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
    @State private var selectedTime = Date()

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            
            Text("Your Preferences")
                .font(.system(size: 28, weight: .bold))
            
            ScrollView {
                VStack(spacing: 20) {
                    // Activity Preferences
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorite Activities")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black.opacity(0.9))
                        
                        VStack(spacing: 10) {
                            ForEach(Activity.allCases, id: \.self) { activity in
                                ActivityToggle(
                                    activity: activity,
                                    isSelected: viewModel.userPreferences.preferredActivities.contains(activity.rawValue),
                                    onChange: { isSelected in
                                        if isSelected {
                                            if !viewModel.userPreferences.preferredActivities.contains(activity.rawValue) {
                                                viewModel.userPreferences.preferredActivities.append(activity.rawValue)
                                            }
                                        } else {
                                            viewModel.userPreferences.preferredActivities.removeAll { $0 == activity.rawValue }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(12)
                    
                    // Notification Preferences
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Enable Notifications")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black.opacity(0.9))
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.userPreferences.enableNotifications)
                                .tint(.accentColor)
                        }
                        
                        if viewModel.userPreferences.enableNotifications {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Suggestion Time")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black.opacity(0.7))
                                
                                DatePicker(
                                    "Time",
                                    selection: viewModel.userPreferences.notificationTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .tint(.accentColor)
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
                .foregroundColor(isSelected ? .accentColor : .gray.opacity(0.5))
            
            Text(activity.rawValue)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
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
