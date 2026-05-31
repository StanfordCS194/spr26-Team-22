import SwiftUI

struct ContactTagPickerView: View {
    @Binding var selectedTags: [ContactTag]
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var expandedCategories: Set<TagCategory> = []

    private let defaultSubcategories: [TagSubcategory] = [
        .college, .highSchool, .currentColleague, .childhoodFriend, .roommate, .friendGroup
    ]

    var body: some View {
        NavigationStack {
            List {
                if !selectedTags.isEmpty && searchQuery.isEmpty {
                    selectedSection
                }

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { onDone(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var selectedSection: some View {
        Section("Selected") {
            ForEach(selectedTags.indices, id: \.self) { idx in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(
                            selectedTags[idx].subcategory.defaultName,
                            systemImage: selectedTags[idx].parentCategory.icon
                        )
                        .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            selectedTags.remove(at: idx)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if selectedTags[idx].subcategory.supportsCustomLabel {
                        TextField(
                            selectedTags[idx].subcategory.customLabelPlaceholder,
                            text: Binding(
                                get: { selectedTags[idx].customLabel ?? "" },
                                set: { selectedTags[idx].customLabel = $0.isEmpty ? nil : $0 }
                            )
                        )
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.vertical, 2)
            }
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
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                } label: {
                    HStack {
                        Image(systemName: category.icon)
                            .frame(width: 20)
                        Text(category.rawValue)
                            .textCase(nil)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
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
                ForEach(filtered) { sub in
                    subcategoryRow(sub)
                }
            }
        }
    }

    // MARK: - Reusable components

    private func chipButton(_ sub: TagSubcategory) -> some View {
        let isSelected = selectedTags.contains { $0.subcategory == sub }
        return Button {
            toggleTag(sub)
        } label: {
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
            Button {
                toggleTag(sub)
            } label: {
                HStack {
                    Text(sub.defaultName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? sub.parent.color : Color.secondary)
                }
            }
            .buttonStyle(.plain)

            if isSelected, sub.supportsCustomLabel,
               let idx = selectedTags.firstIndex(where: { $0.subcategory == sub }) {
                TextField(sub.customLabelPlaceholder, text: Binding(
                    get: { selectedTags[idx].customLabel ?? "" },
                    set: { selectedTags[idx].customLabel = $0.isEmpty ? nil : $0 }
                ))
                .font(.subheadline)
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Helpers

    private func toggleTag(_ sub: TagSubcategory) {
        if let idx = selectedTags.firstIndex(where: { $0.subcategory == sub }) {
            selectedTags.remove(at: idx)
        } else {
            selectedTags.append(ContactTag(subcategory: sub, customLabel: nil))
        }
    }
}
