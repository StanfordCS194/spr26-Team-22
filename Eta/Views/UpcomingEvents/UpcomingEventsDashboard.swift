import SwiftUI

struct UpcomingEventsDashboard: View {
    let viewModel: UpcomingEventsViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingAddSheet = false
    @State private var editingHangout: ScheduledHangout?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.upcomingItems.isEmpty {
                    ContentUnavailableView(
                        "No upcoming events",
                        systemImage: "calendar",
                        description: Text("When you schedule a hangout, it'll appear here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.upcomingItems) { item in
                            Button {
                                editingHangout = item.hangout
                            } label: {
                                UpcomingEventCardView(item: item)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteHangout(item.hangout) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        EventHistoryView(items: viewModel.allItems)
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
        .sheet(isPresented: $showingAddSheet) {
            HangoutFormSheet(
                contacts: viewModel.contacts,
                displayName: { viewModel.contactDisplayName(for: $0) },
                onSend: { contact, activity, interval in
                    // TODO: save hangout + invoke InviteService.sendMessage(for:)
                }
            )
        }
        .sheet(item: $editingHangout) { hangout in
            HangoutFormSheet(
                contacts: viewModel.contacts,
                displayName: { viewModel.contactDisplayName(for: $0) },
                editingHangout: hangout,
                onSend: { contact, activity, interval in
                    // TODO: overwrite existing hangout + send updated invite
                }
            )
        }
    }
}
