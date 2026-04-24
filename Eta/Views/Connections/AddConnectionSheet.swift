import SwiftUI

struct AddConnectionSheet: View {
    let viewModel: ConnectionsViewModel
    let analyticsService: AnalyticsService

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedIDs: Set<String> = []
    @State private var permissionRequestTime: Date?
    @State private var isInitialAdd: Bool = false

    private var navigationTitle: String {
        switch selectedIDs.count {
        case 0:  return "Add Friend"
        case 1:  return "Add 1 Friend"
        default: return "Add \(selectedIDs.count) Friends"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isPermissionDenied {
                    permissionDeniedView
                } else {
                    contactList
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        let selected = viewModel.searchResults.filter { selectedIDs.contains($0.id) }
                        
                        // Track each connection added
                        for contact in selected {
                            analyticsService.logConnectionAdded(
                                contactName: contact.displayName,
                                totalContacts: viewModel.contacts.count + selectedIDs.count,
                                totalAvailable: viewModel.contacts.count + viewModel.searchResults.count,
                                isInitialAdd: isInitialAdd
                            )
                        }
                        
                        viewModel.addContacts(selected)
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            isInitialAdd = viewModel.contacts.isEmpty
            // Track contacts permission request
            analyticsService.logPermissionRequested(type: "Contacts")
            permissionRequestTime = Date()
            
            await viewModel.requestContactsAccess()
            
            // Track permission result
            if let requestTime = permissionRequestTime {
                let timeElapsed = Date().timeIntervalSince(requestTime)
                
                if viewModel.isPermissionDenied {
                    analyticsService.logPermissionDenied(type: "Contacts", timeElapsed: timeElapsed)
                } else {
                    // Determine if all contacts or selected
                    // Note: iOS doesn't expose this directly, so we approximate based on count
                    analyticsService.logPermissionGranted(
                        type: "Contacts",
                        timeElapsed: timeElapsed,
                        additionalInfo: [
                            "type": "all" // iOS 18+ doesn't distinguish anymore
                        ]
                    )
                }
            }
            
            await viewModel.loadAllContacts()
        }
        .trackScreen("AddConnectionSheet", analytics: analyticsService)
    }

    // MARK: - Subviews

    private var contactList: some View {
        List {
            Section {
                Label(
                    "Eta uses your contacts to find friends by name. Contact data stays on your device.",
                    systemImage: "person.crop.circle.badge.checkmark"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if viewModel.isLoadingContacts {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.searchResults.isEmpty {
                Text(query.isEmpty ? "No contacts available." : "No contacts found for \"\(query)\".")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(viewModel.searchResults) { item in
                    Button {
                        if selectedIDs.contains(item.id) {
                            selectedIDs.remove(item.id)
                        } else {
                            selectedIDs.insert(item.id)
                        }
                    } label: {
                        HStack {
                            Text(item.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selectedIDs.contains(item.id)
                                    ? "checkmark.circle.fill"
                                    : "circle")
                                .foregroundStyle(selectedIDs.contains(item.id)
                                    ? Color.accentColor
                                    : Color.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search contacts")
        .onChange(of: query) { _, newValue in
            viewModel.searchContacts(query: newValue)
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView(
            "Contacts Access Required",
            systemImage: "person.crop.circle.badge.exclamationmark",
            description: Text("To add friends, allow Eta to access your contacts in Settings.")
        )
    }
}
