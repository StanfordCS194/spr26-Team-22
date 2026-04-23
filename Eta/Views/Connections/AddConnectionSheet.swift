import SwiftUI

struct AddConnectionSheet: View {
    let viewModel: ConnectionsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedIDs: Set<String> = []

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
                        viewModel.addContacts(selected)
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await viewModel.requestContactsAccess()
            await viewModel.loadAllContacts()
        }
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
