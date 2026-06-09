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
    /// First slot touched during a drag selection in edit mode.
    @State private var dragStartSlot: Int?
    /// Current slot under the user's drag in edit mode.
    @State private var dragCurrentSlot: Int?

    /// Height of one availability row, including its vertical padding.
    private let availabilityRowHeight: CGFloat = 21
    /// Minutes represented by each availability row.
    private let slotDurationMinutes = 30
    /// Horizontal inset where the colored availability cells begin.
    private let availabilityBlockLeadingInset: CGFloat = 68
    /// Right inset for colored availability cells.
    private let availabilityBlockTrailingInset: CGFloat = 10
    
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

                    if !hasDisplayableContent && !isEditingAvailability {
                        EmptyAvailabilityState()
                    } else {
                        if isEditingAvailability {
                            availabilityEntryModeControl
                        }

                        legend

                        VStack(spacing: 0) {
                            ForEach(displayedSlots, id: \.self) { slot in
                                if let interval = slotInterval(for: slot) {
                                    HourAvailabilityRow(
                                        label: slotTimeLabel(for: interval.start),
                                        status: status(for: interval),
                                        detail: detail(for: interval),
                                        isEditing: isEditingAvailability,
                                        isDragSelected: dragSelectedSlots.contains(slot),
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
                        .overlay(alignment: .topLeading) {
                            scheduledBlockOverlay
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
            .navigationBarTitleDisplayMode(.inline)
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

    /// 30-minute slots displayed in the day grid.
    private var displayedSlots: [Int] {
        Array(0..<48)
    }

    /// Whether the selected day has availability or scheduled events to display.
    private var hasDisplayableContent: Bool {
        viewModel.hasDisplayableAvailability(on: selectedDate)
            || viewModel.hasScheduledHangout(on: selectedDate)
    }

    /// Earliest date users can choose for availability entry.
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// End repeat date passed to new recurring blocks.
    private var selectedRepeatEndDate: Date? {
        entryMode == .repeatWeekly && hasRepeatEndDate ? repeatEndDate : nil
    }

    /// Slots currently included in the drag preview.
    private var dragSelectedSlots: Set<Int> {
        guard let dragStartSlot, let dragCurrentSlot else { return [] }
        let lower = min(dragStartSlot, dragCurrentSlot)
        let upper = max(dragStartSlot, dragCurrentSlot)
        return Set(displayedSlots.filter { lower <= $0 && $0 <= upper })
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

    /// Single scheduled-event blocks layered over the half-hour grid rows.
    private var scheduledBlockOverlay: some View {
        GeometryReader { proxy in
            ForEach(viewModel.scheduledDisplayBlocks(on: selectedDate)) { block in
                if let layout = scheduledBlockLayout(for: block) {
                    ScheduledAvailabilityBlock(label: block.label)
                        .frame(
                            width: max(0, proxy.size.width - availabilityBlockLeadingInset - availabilityBlockTrailingInset),
                            height: max(availabilityRowHeight, layout.height)
                        )
                        .offset(x: availabilityBlockLeadingInset, y: layout.yOffset)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Slider that edits the shared hangout duration setting.
    private var activityDurationEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preferred hangout length")
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
                Text("Preferred hangout length")
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

    /// Builds a 30-minute interval for a displayed grid row.
    private func slotInterval(for slot: Int) -> DateInterval? {
        let calendar = Calendar.current
        let minutesFromStartOfDay = slot * slotDurationMinutes
        guard let startOfDay = calendar.dateInterval(of: .day, for: selectedDate)?.start,
              let start = calendar.date(byAdding: .minute, value: minutesFromStartOfDay, to: startOfDay),
              let end = calendar.date(byAdding: .minute, value: slotDurationMinutes, to: start)
        else { return nil }

        return DateInterval(start: start, end: end)
    }

    /// Keeps the selected day inside the visible date range.
    private func moveSelectionToTodayIfNeeded() {
        guard selectedDate < today else { return }
        selectedDate = today
    }

    /// Updates the highlighted slot range while the user drags through the grid.
    private func updateDragSelection(from startLocation: CGPoint, to currentLocation: CGPoint) {
        guard isEditingAvailability,
              let startSlot = slot(atYPosition: startLocation.y),
              let currentSlot = slot(atYPosition: currentLocation.y)
        else { return }

        if dragStartSlot == nil {
            dragStartSlot = startSlot
        }
        dragCurrentSlot = currentSlot
    }

    /// Applies the selected drag range using the same recurrence settings as tap entry.
    private func applyDragSelection() {
        defer {
            dragStartSlot = nil
            dragCurrentSlot = nil
        }

        let slots = dragSelectedSlots.sorted()
        guard !slots.isEmpty else { return }

        withAnimation {
            for slot in slots {
                guard let interval = slotInterval(for: slot),
                      !viewModel.isScheduled(during: interval),
                      !viewModel.isSkippedRecurring(during: interval)
                else { continue }

                toggleAvailability(during: interval)
            }
        }
    }

    /// Converts a drag y-coordinate into the corresponding displayed slot.
    private func slot(atYPosition yPosition: CGFloat) -> Int? {
        guard yPosition >= 0 else { return nil }
        let index = Int(yPosition / availabilityRowHeight)
        guard displayedSlots.indices.contains(index) else { return nil }
        return displayedSlots[index]
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

    /// Returns the row label shown inside a free availability grid block.
    private func detail(for interval: DateInterval) -> String {
        if viewModel.isScheduled(during: interval) {
            return ""
        }

        if viewModel.isFree(during: interval) {
            return viewModel.isRecurringFree(during: interval) ? recurringDetail(for: interval) : "Free"
        }

        if viewModel.isSkippedRecurring(during: interval) {
            return "Skipped"
        }

        return ""
    }

    /// Computes the vertical position for a scheduled block inside the selected day.
    private func scheduledBlockLayout(for block: ScheduledAvailabilityDisplayBlock) -> (yOffset: CGFloat, height: CGFloat)? {
        guard let dayStart = Calendar.current.dateInterval(of: .day, for: selectedDate)?.start else {
            return nil
        }

        let slotSeconds = TimeInterval(slotDurationMinutes * 60)
        let startOffset = max(0, block.startDate.timeIntervalSince(dayStart))
        let duration = max(0, block.endDate.timeIntervalSince(block.startDate))

        return (
            yOffset: CGFloat(startOffset / slotSeconds) * availabilityRowHeight,
            height: CGFloat(duration / slotSeconds) * availabilityRowHeight
        )
    }

    /// Formats the left-hand time label for the grid, showing only full hours.
    private func slotTimeLabel(for date: Date) -> String {
        guard Calendar.current.component(.minute, from: date) == 0 else {
            return ""
        }

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

/// A scheduled event drawn as one continuous block across the grid.
private struct ScheduledAvailabilityBlock: View {
    let label: String

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.pink)
            .overlay(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            }
    }
}

/// One row in the availability grid.
private struct HourAvailabilityRow: View {
    /// Display states supported by an availability row.
    enum Status: Equatable {
        case free
        case recurringFree
        case skippedRecurring
        case scheduled
        case unavailable
    }

    /// Left-side time label.
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

            RoundedRectangle(cornerRadius: blockCornerRadius)
                .fill(fillColor)
                .frame(height: blockHeight)
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
                    RoundedRectangle(cornerRadius: blockCornerRadius)
                        .stroke(isDragSelected ? Color.accentColor : borderColor, lineWidth: isDragSelected ? 2 : 1)
                )
                .overlay(alignment: .trailing) {
                    if isEditing && status != .scheduled {
                        rowControls
                            .padding(.trailing, 10)
                    }
                }
        }
        .padding(.vertical, verticalPadding)
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

    /// Keeps two 30-minute rows close to the old one-hour visual height.
    private var blockHeight: CGFloat {
        status == .scheduled ? 21 : 17
    }

    /// Scheduled slots stack tightly so one event reads as a single block.
    private var verticalPadding: CGFloat {
        status == .scheduled ? 0 : 2
    }

    /// Scheduled rows stack into continuous blocks without scalloped internal corners.
    private var blockCornerRadius: CGFloat {
        status == .scheduled ? 0 : 4
    }

    /// Fill color associated with the row status.
    private var fillColor: Color {
        switch status {
        case .free: return .green.opacity(0.65)
        case .recurringFree: return .teal.opacity(0.75)
        case .skippedRecurring: return .gray.opacity(0.45)
        case .scheduled: return .clear
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
