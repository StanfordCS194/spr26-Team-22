import SwiftUI

struct SuggestionView: View {
    let viewModel: SuggestionViewModel
    let analyticsService: AnalyticsService

    @Environment(\.scenePhase) private var scenePhase
    @State private var scheduleStartTime: Date?
    @State private var showingPhotoSheet = false
    @State private var activeSuggestionForPhoto: Suggestion?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch viewModel.scheduleState {
                    case .accepted:
                        AcceptedView()
                    case .invitationSent(let friendName):
                        InvitationSentView(friendName: friendName, onDone: { viewModel.done() })
                    case .idle:
                        if let suggestion = viewModel.suggestion {
                            SuggestionCard(
                                displayName: viewModel.displayName(for: suggestion),
                                timeLabel: viewModel.timeLabel(for: suggestion),
                                suggestion: suggestion,
                                latestPhotoData: viewModel.latestPhotoData(for: suggestion),
                                onDismiss: {
                                    analyticsService.logSuggestionDismissed(contactName: viewModel.displayName(for: suggestion))
                                    viewModel.dismiss()
                                },
                                onSchedule: {
                                    let name = viewModel.displayName(for: suggestion)
                                    let hour = Calendar.current.component(.hour, from: suggestion.proposedTime.start)
                                    let timeOfDay: String
                                    switch hour {
                                    case 5..<12: timeOfDay = "morning"
                                    case 12..<18: timeOfDay = "afternoon"
                                    default:      timeOfDay = "evening"
                                    }
                                    analyticsService.logInvitationInitiated(
                                        contactName: name,
                                        activity: suggestion.activityDescription,
                                        timeOfDay: timeOfDay,
                                        isFreeSlotSuggested: true
                                    )
                                    scheduleStartTime = Date()
                                    viewModel.schedule()
                                },
                                onCameraCapture: {
                                    activeSuggestionForPhoto = suggestion
                                    showingPhotoSheet = true
                                },
                                analyticsService: analyticsService
                            )
                            .onAppear {
                                analyticsService.logSuggestionViewed(
                                    contactName: viewModel.displayName(for: suggestion),
                                    daysSinceLastHangout: nil
                                )
                            }
                        } else {
                            ContentUnavailableView(
                                "Nothing to suggest right now",
                                systemImage: "calendar.badge.clock",
                                description: Text("We'll suggest a hangout when you have free time and a friend to catch up with.")
                            )
                        }
                    }
                }
            }
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.refresh()

            if let suggestion = viewModel.suggestion {
                analyticsService.logSuggestionsGenerated(
                    count: 1,
                    contactNames: [viewModel.displayName(for: suggestion)]
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
        .sheet(isPresented: $showingPhotoSheet) {
            if let suggestion = activeSuggestionForPhoto {
                ReminderPhotoSheet(
                    activity: Activity(rawValue: suggestion.activityDescription) ?? .walk,
                    hangoutID: nil,
                    existingPhotos: viewModel.photos(for: suggestion),
                    onSave: { data in
                        viewModel.savePhoto(data, for: suggestion)
                        showingPhotoSheet = false
                    },
                    onDismiss: { showingPhotoSheet = false }
                )
            }
        }
        .trackScreen("SuggestionView", analytics: analyticsService)
    }
}

// MARK: - Confirmation views

private struct AcceptedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Scheduling your hangout...")
                .font(.title)
                .fontWeight(.semibold)
            Text("Setting up your calendar event and invitation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct InvitationSentView: View {
    let friendName: String
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Invitation sent to \(friendName)!")
                    .font(.title)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text("You'll get a notification when they respond.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
