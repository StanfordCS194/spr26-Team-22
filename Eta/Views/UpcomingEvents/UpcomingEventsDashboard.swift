import SwiftUI

struct UpcomingEventsDashboard: View {
    let viewModel: UpcomingEventsViewModel
    let photoRepository: ActivityPhotoRepository
    let analyticsService: AnalyticsService
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingAddSheet = false
    @State private var editingItem: HangoutDisplayItem? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.upcomingItems.isEmpty && viewModel.pendingInvites.isEmpty {
                    ContentUnavailableView(
                        "No upcoming events",
                        systemImage: "calendar",
                        description: Text("When you schedule a hangout, it'll appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.pendingInvites) { invite in
                                ReceivedInviteCard(
                                    invite: invite,
                                    onAccept: { Task { await viewModel.respond(to: invite, accepted: true) } },
                                    onDecline: { Task { await viewModel.respond(to: invite, accepted: false) } }
                                )
                                .padding(.horizontal)
                            }
                            ForEach(viewModel.upcomingItems) { item in
                                UpcomingEventCardView(
                                    item: item,
                                    photoRepository: photoRepository,
                                    analyticsService: analyticsService,
                                    onEdit: { editingItem = item },
                                    onDelete: {
                                        analyticsService.logEventDeleted(activity: item.hangout.activity)
                                        viewModel.deleteEvent(item.hangout)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        EventHistoryView(items: viewModel.allItems, photoRepository: photoRepository)
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduledHangoutsDidChange)) { _ in
            Task { await viewModel.refresh() }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditEventSheet(
                mode: .add(viewModel.contacts),
                onSave: { contact, activity, interval in
                    analyticsService.logEventCreated(activity: activity, isEdit: false)
                    await viewModel.addEvent(contact: contact, activity: activity, interval: interval)
                },
                onSuggestActivity: { contact, proposedTime in
                    try await viewModel.suggestActivity(for: contact, proposedTime: proposedTime)
                }
            )
        }
        .sheet(item: $editingItem) { item in
            AddEditEventSheet(
                mode: .edit(item),
                onSave: { _, activity, interval in
                    analyticsService.logEventCreated(activity: activity, isEdit: true)
                    await viewModel.editEvent(item.hangout, activity: activity, interval: interval)
                },
                onSuggestActivity: { contact, proposedTime in
                    try await viewModel.suggestActivity(for: contact, proposedTime: proposedTime)
                }
            )
        }
        .trackScreen("UpcomingEventsDashboard", analytics: analyticsService)
    }
}
