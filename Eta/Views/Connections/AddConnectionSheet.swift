import SwiftUI

struct AddConnectionSheet: View {
    let viewModel: ConnectionsViewModel
    let analyticsService: AnalyticsService

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedIDs: Set<String> = []
    @State private var permissionRequestTime: Date?
    @State private var isInitialAdd: Bool = false
    @State private var navigatingToTagStep = false

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
            .navigationDestination(isPresented: $navigatingToTagStep) {
                let selected = viewModel.searchResults.filter { selectedIDs.contains($0.id) }
                TagContactsStep(
                    selectedItems: selected,
                    onAdd: { tags in
                        for contact in selected {
                            analyticsService.logConnectionAdded(
                                contactName: contact.displayName,
                                totalContacts: viewModel.contacts.count + selectedIDs.count,
                                totalAvailable: viewModel.contacts.count + viewModel.searchResults.count,
                                isInitialAdd: isInitialAdd
                            )
                        }
                        viewModel.addContacts(selected, tags: tags)
                        dismiss()
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(selectedIDs.count == 1 ? "Next" : "Add") {
                        if selectedIDs.count == 1 {
                            navigatingToTagStep = true
                        } else {
                            let selected = viewModel.searchResults.filter { selectedIDs.contains($0.id) }
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

// MARK: - Tag step

private struct TagContactsStep: View {
    let selectedItems: [ContactPickerItem]
    let onAdd: ([ContactTag]) -> Void

    @State private var selectedTags: [ContactTag] = []
    @State private var customLabels: [TagSubcategory: String] = [:]
    @State private var searchQuery = ""
    @State private var expandedCategories: Set<TagCategory> = []

    private let defaultSubcategories: [TagSubcategory] = [
        .college, .highSchool, .currentColleague, .childhoodFriend, .roommate, .friendGroup
    ]

    var body: some View {
        List {
            contactSummarySection
            if searchQuery.isEmpty {
                commonSection
                categoryBrowser
            } else {
                searchResultsSection
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchQuery, prompt: "Search tags")
        .navigationTitle("Add context")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add") {
                    var tags = selectedTags
                    for idx in tags.indices {
                        let sub = tags[idx].subcategory
                        if let label = customLabels[sub], !label.isEmpty {
                            tags[idx].customLabel = label
                        }
                    }
                    onAdd(tags)
                }
                .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private var contactSummarySection: some View {
        Section {
            let names = selectedItems.map(\.displayName)
            let summary: String = {
                switch names.count {
                case 1:  return names[0]
                case 2:  return "\(names[0]) and \(names[1])"
                default: return "\(names[0]), \(names[1]) and \(names.count - 2) more"
                }
            }()
            Label("Adding \(summary). Tags apply to all.", systemImage: "person.2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var commonSection: some View {
        Section("Common") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(defaultSubcategories) { sub in
                    chipButton(sub)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var categoryBrowser: some View {
        ForEach(TagCategory.allCases) { category in
            let subcategories = TagSubcategory.allCases.filter { $0.parent == category }
            let isExpanded = expandedCategories.contains(category)

            Section {
                if isExpanded {
                    ForEach(subcategories) { sub in
                        subcategoryRow(sub)
                    }
                }
            } header: {
                Button {
                    if isExpanded { expandedCategories.remove(category) }
                    else { expandedCategories.insert(category) }
                } label: {
                    HStack {
                        Image(systemName: category.icon).frame(width: 20)
                        Text(category.rawValue).textCase(nil)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        let filtered = TagSubcategory.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchQuery)
        }
        Section {
            if filtered.isEmpty {
                Text("No tags matching \"\(searchQuery)\"")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(filtered) { sub in subcategoryRow(sub) }
            }
        }
    }

    private func chipButton(_ sub: TagSubcategory) -> some View {
        let isSelected = selectedTags.contains { $0.subcategory == sub }
        return Button { toggleTag(sub) } label: {
            Text(sub.defaultName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? sub.parent.color : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func subcategoryRow(_ sub: TagSubcategory) -> some View {
        let isSelected = selectedTags.contains { $0.subcategory == sub }
        return VStack(alignment: .leading, spacing: 8) {
            Button { toggleTag(sub) } label: {
                HStack {
                    Text(sub.defaultName).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? sub.parent.color : Color.secondary)
                }
            }
            .buttonStyle(.plain)

            if isSelected && sub.supportsCustomLabel {
                TextField(sub.customLabelPlaceholder, text: Binding(
                    get: { customLabels[sub] ?? "" },
                    set: { customLabels[sub] = $0 }
                ))
                .font(.subheadline)
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func toggleTag(_ sub: TagSubcategory) {
        if let idx = selectedTags.firstIndex(where: { $0.subcategory == sub }) {
            selectedTags.remove(at: idx)
        } else {
            selectedTags.append(ContactTag(subcategory: sub, customLabel: nil))
        }
    }
}
