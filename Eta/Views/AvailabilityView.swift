//  Created by Lauren Hamilton on 5/12/26.
//
import Foundation
import SwiftUI

/// Availability tab for entering free time, choosing hangout length, and viewing scheduled blocks.
struct AvailabilityView: View {

    let viewModel: AvailabilityViewModel
    /// Day currently shown in the availability grid.
    @State private var selectedDate = Date()
    /// Controls whether schedule blocks can be selected and deselected.
    @State private var isEditingAvailability = false
    /// Controls whether newly selected availability is one-time or recurring.
    @State private var entryMode: AvailabilityEntryMode = .oneTime
    /// Whether newly selected recurring availability has an end date.
    @State private var hasRepeatEndDate = false
    /// End date used for newly selected recurring availability.
    @State private var repeatEndDate = Date()
    /// First hour touched during a drag selection in edit mode.
    @State private var dragStartHour: Int?
    /// Current hour under the user's drag in edit mode.
    @State private var dragCurrentHour: Int?

    /// Height of one availability row, including its vertical padding.
    private let availabilityRowHeight: CGFloat = 42
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DatePicker(
                        "Day",
                        selection: $selectedDate,
                        in: today...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)

                    activityDurationEditor

                    if !viewModel.hasDisplayableAvailability(on: selectedDate) && !isEditingAvailability {
                        EmptyAvailabilityState()
                    } else {
                        if isEditingAvailability {
                            availabilityEntryModeControl
                        }

                        legend

                        VStack(spacing: 0) {
                            ForEach(displayedHours, id: \.self) { hour in
                                if let interval = hourInterval(for: hour) {
                                    HourAvailabilityRow(
                                        label: hourLabel(for: interval.start),
                                        status: status(for: interval),
                                        detail: detail(for: interval),
                                        isEditing: isEditingAvailability,
                                        isDragSelected: dragSelectedHours.contains(hour),
                                        onToggle: {
                                            withAnimation {
                                                toggleAvailability(during: interval)
                                            }
                                        },
                                        onSkip: {
                                            withAnimation {
                                                viewModel.skipRecurringAvailability(during: interval)
                                            }
                                        },
                                        onUnskip: {
                                            withAnimation {
                                                viewModel.unskipRecurringAvailability(during: interval)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .coordinateSpace(name: "availability-grid")
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8, coordinateSpace: .named("availability-grid"))
                                .onChanged { value in
                                    updateDragSelection(from: value.startLocation, to: value.location)
                                }
                                .onEnded { _ in
                                    applyDragSelection()
                                }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                    }

                    Button {
                        withAnimation {
                            isEditingAvailability.toggle()
                        }
                    } label: {
                        Label(
                            isEditingAvailability ? "Done" : "Change Availability",
                            systemImage: isEditingAvailability ? "checkmark" : "square.grid.3x3"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Availability")
            .task {
                moveSelectionToTodayIfNeeded()
                await viewModel.loadAvailability()
            }
            .onReceive(NotificationCenter.default.publisher(for: .scheduledHangoutsDidChange)) { _ in
                Task {
                    await viewModel.loadAvailability()
                }
            }
        }
    }

    /// Hours displayed in the day grid.
    private var displayedHours: [Int] {
        Array(5..<24)
    }

    /// Earliest date users can choose for availability entry.
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// End repeat date passed to new recurring blocks.
    private var selectedRepeatEndDate: Date? {
        entryMode == .repeatWeekly && hasRepeatEndDate ? repeatEndDate : nil
    }

    /// Hours currently included in the drag preview.
    private var dragSelectedHours: Set<Int> {
        guard let dragStartHour, let dragCurrentHour else { return [] }
        let lower = min(dragStartHour, dragCurrentHour)
        let upper = max(dragStartHour, dragCurrentHour)
        return Set(displayedHours.filter { lower <= $0 && $0 <= upper })
    }

    /// Color legend for the availability grid.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                LegendItem(color: .green, label: "Free")
                LegendItem(color: .teal.opacity(0.75), label: "Free (recurring)")
            }

            HStack(spacing: 16) {
                LegendItem(color: .gray.opacity(0.45), label: "Skipped (recurring)")
                LegendItem(color: .pink, label: "Scheduled")
                LegendItem(color: Color(.systemBackground), label: "Unavailable", bordered: true)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Slider that edits the shared hangout duration setting.
    private var activityDurationEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hangout length")
                    .font(.headline)
                Spacer()
                Text(viewModel.activityDurationLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: durationSliderBinding,
                in: 15...360,
                step: 15
            ) {
                Text("Hangout length")
            } minimumValueLabel: {
                Text("15m")
                    .font(.caption)
            } maximumValueLabel: {
                Text("6h")
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Controls whether newly selected free blocks are one-time or recurring.
    private var availabilityEntryModeControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Availability type", selection: $entryMode) {
                ForEach(AvailabilityEntryMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if entryMode == .repeatWeekly {
                Toggle("Repeat end date (optional)", isOn: $hasRepeatEndDate)
                    .toggleStyle(.switch)

                if hasRepeatEndDate {
                    DatePicker(
                        "Repeat until",
                        selection: $repeatEndDate,
                        in: selectedDate...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: selectedDate) { newDate in
            if repeatEndDate < newDate {
                repeatEndDate = newDate
            }
        }
    }

    /// Bridge between the view model's integer-minute setting and SwiftUI's `Slider` API.
    private var durationSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.activityDurationMinutes) },
            set: { viewModel.setActivityDurationMinutes(Int($0)) }
        )
    }

    /// Builds a one-hour interval for a displayed grid row.
    private func hourInterval(for hour: Int) -> DateInterval? {
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate),
              let end = calendar.date(byAdding: .hour, value: 1, to: start)
        else { return nil }

        return DateInterval(start: start, end: end)
    }

    /// Keeps the selected day inside the visible date range.
    private func moveSelectionToTodayIfNeeded() {
        guard selectedDate < today else { return }
        selectedDate = today
    }

    /// Updates the highlighted hour range while the user drags through the grid.
    private func updateDragSelection(from startLocation: CGPoint, to currentLocation: CGPoint) {
        guard isEditingAvailability,
              let startHour = hour(atYPosition: startLocation.y),
              let currentHour = hour(atYPosition: currentLocation.y)
        else { return }

        if dragStartHour == nil {
            dragStartHour = startHour
        }
        dragCurrentHour = currentHour
    }

    /// Applies the selected drag range using the same recurrence settings as tap entry.
    private func applyDragSelection() {
        defer {
            dragStartHour = nil
            dragCurrentHour = nil
        }

        let hours = dragSelectedHours.sorted()
        guard !hours.isEmpty else { return }

        withAnimation {
            for hour in hours {
                guard let interval = hourInterval(for: hour),
                      !viewModel.isScheduled(during: interval),
                      !viewModel.isSkippedRecurring(during: interval)
                else { continue }

                toggleAvailability(during: interval)
            }
        }
    }

    /// Converts a drag y-coordinate into the corresponding displayed hour.
    private func hour(atYPosition yPosition: CGFloat) -> Int? {
        guard yPosition >= 0 else { return nil }
        let index = Int(yPosition / availabilityRowHeight)
        guard displayedHours.indices.contains(index) else { return nil }
        return displayedHours[index]
    }

    /// Applies the availability toggle for one grid interval.
    private func toggleAvailability(during interval: DateInterval) {
        if viewModel.isRecurringFree(during: interval) {
            viewModel.stopRecurringAvailability(during: interval)
        } else {
            viewModel.toggleAvailability(
                during: interval,
                repeatsWeekly: entryMode == .repeatWeekly,
                repeatEndDate: selectedRepeatEndDate
            )
        }
    }

    /// Resolves the visual state for a grid row.
    private func status(for interval: DateInterval) -> HourAvailabilityRow.Status {
        if viewModel.isScheduled(during: interval) {
            return .scheduled
        }

        if viewModel.isSkippedRecurring(during: interval) {
            return .skippedRecurring
        }

        if viewModel.isRecurringFree(during: interval) {
            return .recurringFree
        }

        if viewModel.isFree(during: interval) {
            return .free
        }

        return .unavailable
    }

    /// Returns the row label shown inside a free or scheduled grid block.
    private func detail(for interval: DateInterval) -> String {
        let scheduledLabels = viewModel.scheduledLabels(during: interval)
        if !scheduledLabels.isEmpty {
            return scheduledLabels.joined(separator: ", ")
        }

        if viewModel.isFree(during: interval) {
            return viewModel.isRecurringFree(during: interval) ? recurringDetail(for: interval) : "Free"
        }

        if viewModel.isSkippedRecurring(during: interval) {
            return "Skipped"
        }

        return ""
    }

    /// Formats the left-hand hour label for the grid.
    private func hourLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

    /// Label shown inside recurring availability blocks.
    private func recurringDetail(for interval: DateInterval) -> String {
        guard let endDate = viewModel.recurringEndDate(during: interval) else {
            return "Free (recurring)"
        }

        return "Free (recurring until \(shortDateFormatter.string(from: endDate)))"
    }

    /// Short date formatter for recurring labels.
    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter
    }

}

/// One row in the hour-by-hour availability grid.
private struct HourAvailabilityRow: View {
    /// Display states supported by an hourly availability row.
    enum Status: Equatable {
        case free
        case recurringFree
        case skippedRecurring
        case scheduled
        case unavailable
    }

    /// Left-side hour label.
    let label: String
    /// Visual state of the row.
    let status: Status
    /// Optional text shown inside the colored row block.
    let detail: String
    /// Whether the row should visually indicate it can be toggled.
    let isEditing: Bool
    /// Whether this row is included in the current drag preview.
    let isDragSelected: Bool
    /// Called when the row is selected in edit mode.
    let onToggle: () -> Void
    /// Called when a recurring row should be skipped only for the displayed day.
    let onSkip: () -> Void
    /// Called when a skipped recurring row should be restored.
    let onUnskip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)

            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .frame(height: 34)
                .overlay(alignment: .leading) {
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .padding(.leading, 10)
                            .padding(.trailing, detailTrailingPadding)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isDragSelected ? Color.accentColor : borderColor, lineWidth: isDragSelected ? 2 : 1)
                )
                .overlay(alignment: .trailing) {
                    if isEditing && status != .scheduled {
                        rowControls
                            .padding(.trailing, 10)
                    }
                }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing, status != .scheduled, status != .skippedRecurring else { return }
            onToggle()
        }
    }

    /// Editing controls shown inside the row.
    @ViewBuilder
    private var rowControls: some View {
        if status == .recurringFree {
            HStack(spacing: 8) {
                Button("Skip") {
                    onSkip()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button {
                    onToggle()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)
            }
        } else if status == .skippedRecurring {
            Button("Unskip") {
                onUnskip()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .controlSize(.mini)
        } else {
            Image(systemName: status.isAvailable ? "xmark.circle.fill" : "circle")
                .foregroundStyle(status.isAvailable ? .green : .secondary)
        }
    }

    /// Space reserved so row text does not run underneath edit controls.
    private var detailTrailingPadding: CGFloat {
        guard isEditing else { return 10 }

        switch status {
        case .recurringFree: return 96
        case .skippedRecurring: return 74
        case .free, .unavailable: return 38
        case .scheduled: return 10
        }
    }

    /// Fill color associated with the row status.
    private var fillColor: Color {
        switch status {
        case .free: return .green.opacity(0.65)
        case .recurringFree: return .teal.opacity(0.75)
        case .skippedRecurring: return .gray.opacity(0.45)
        case .scheduled: return .pink.opacity(0.55)
        case .unavailable: return Color(.systemBackground)
        }
    }

    /// Border color used to outline unavailable rows.
    private var borderColor: Color {
        switch status {
        case .unavailable: return Color.secondary.opacity(0.25)
        default: return .clear
        }
    }

    /// Text color used inside the row block.
    private var textColor: Color {
        switch status {
        case .free, .recurringFree, .skippedRecurring, .scheduled: return .primary
        case .unavailable: return .secondary
        }
    }
}

private extension HourAvailabilityRow.Status {
    var isAvailable: Bool {
        self == .free || self == .recurringFree
    }
}

private enum AvailabilityEntryMode: String, CaseIterable, Identifiable {
    case oneTime
    case repeatWeekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneTime: return "One Time"
        case .repeatWeekly: return "Repeat Weekly"
        }
    }
}

/// Empty state shown before the user has added free time for the selected day.
private struct EmptyAvailabilityState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("No Availability Indicated")
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Let us know when you're free!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

/// Small color swatch and label used by the availability grid legend.
private struct LegendItem: View {
    /// Swatch color.
    let color: Color
    /// Text shown beside the swatch.
    let label: String
    /// Whether the swatch needs an outline to remain visible.
    var bordered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(bordered ? Color.secondary.opacity(0.4) : .clear, lineWidth: 1)
                )
            Text(label)
        }
    }
}
