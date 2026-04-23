# Eta — MVP Implementation Schedule

Each PR leaves the app in a runnable state and adds visible, testable value.
No PR depends on a future PR to be meaningful.

---

## PR 1 — App scaffold, models, protocols
**Shippable demo:** App opens, two empty tabs ("For You" / "Friends")

Files:
- `Eta/EtaApp.swift` — SwiftData ModelContainer, ViewModel wiring
- `Eta/App/MainTabView.swift` — two-tab TabView with placeholders
- `Eta/Models/TrackedContact.swift` — @Model; stores `givenName`+`familyName` as raw components alongside pre-formatted `name` fallback
- `Eta/Models/HangoutEvent.swift` — parsed calendar event (value type)
- `Eta/Models/RelationshipHealth.swift` — computed score + metadata (value type)
- `Eta/Models/Suggestion.swift` — friend + activity + reason (value type)
- `Eta/Models/Activity.swift` — hardcoded activity enum
- `Eta/Protocols/ImplicitDataProvider.swift`
- `Eta/Protocols/SuggestionStrategy.swift`
- `Eta/Protocols/InviteProvider.swift`
- `Eta/Formatters/ContactFormatter.swift` — locale-aware name formatting via CNContactFormatter; single place in the app that knows about CNContactFormatter

---

## PR 2 — Connections: add and manage tracked friends
**Shippable demo:** Full friends list UX — search contacts, tag, list, remove

Files:
- `Eta/Repositories/ContactRepository.swift` — SwiftData CRUD
- `Eta/ViewModels/ConnectionsViewModel.swift` — receives `ContactFormatter` via injection; exposes formatted name strings to Views
- `Eta/Views/Connections/ConnectionsView.swift` — tracked contacts list, swipe-to-remove
- `Eta/Views/Connections/AddConnectionSheet.swift` — CNContactStore search, inline permission request

---

## PR 3 — Calendar integration and relationship health
**Shippable demo:** Friends list shows "Last seen 12 days ago" / color indicator

Files:
- `Eta/DataProviders/CalendarDataProvider.swift` — EKEventStore, attendee-email matching
- `Eta/Services/RelationshipService.swift` — fans out to [ImplicitDataProvider], computes [RelationshipHealth]
- Updates to `ConnectionsViewModel` — fetches health scores
- Updates to `ConnectionsView` — health indicator UI (label + color dot)

---

## PR 4 — Suggestion engine and For You tab
**Shippable demo:** For You tab shows an opportunity-driven suggestion card ("You have time this afternoon — want to grab coffee with Karan?"), pull-to-refresh works, inbox is empty when there's no free time or no overdue friend

A suggestion requires **both signals**: a free slot in the near-term calendar AND a contact
whose health score exceeds the recency threshold (score ≥ 7). Either signal alone → empty inbox.

Files:
- `Eta/Models/Suggestion.swift` — add `proposedTime: DateInterval`
- `Eta/DataProviders/CalendarDataProvider.swift` — add `findFreeSlot(within:minimumDuration:)`, searches up to 3 days ahead in a 9am–9pm window for a gap ≥ 1 hour
- `Eta/Strategies/RulesSuggestionStrategy.swift` — returns nil if highest score < 7 ("recently saw everyone"); otherwise picks top contact, random activity, tiered reason string
- `Eta/Services/SuggestionService.swift` — checks free slot first, then health; attaches `proposedTime` to strategy result; depends on `CalendarDataProvider` concretely for slot detection
- `Eta/ViewModels/SuggestionViewModel.swift` — `@Observable`; exposes `suggestion`, `isLoading`, `timeLabel`; `refresh() async`, `dismiss()`
- `Eta/Views/Suggestion/SuggestionView.swift` — inbox style; empty state when no suggestion; scene phase observed here via `.onChange(of: scenePhase)`
- `Eta/Views/Suggestion/SuggestionCard.swift` — displays time label + contact + activity; "Yes" disabled (PR 5); "Maybe Later" calls `dismiss()`

---

## PR 5 — Invite flow (end-to-end loop complete)
**Shippable demo:** Tapping "Send Invite" opens iMessage with pre-filled message

Files:
- `Eta/InviteProviders/iMessageInviteProvider.swift` — sms: URL scheme
- `Eta/Services/InviteService.swift` — formats message string, calls InviteProvider
- Updates to `SuggestionViewModel` — expose sendInvite()
- Updates to `SuggestionView` — enable button, wire action

---

## PR 6 — Empty states and MVP hardening
**Shippable demo:** Client-demo ready — no broken states

Covers:
- Empty state views (no friends yet, no suggestion yet)
- Graceful Calendar permission denial (manual-only mode)
- Error handling in RelationshipService + CalendarDataProvider
- App icon, accent color

---

## Status

| PR | Status |
|----|--------|
| PR 1 — Scaffold, models, protocols | [x] Complete |
| PR 2 — Connections                 | [x] Complete    |
| PR 3 — Calendar + health           | [x] Complete    |
| PR 4 — Suggestion engine           | [ ] Not started |
| PR 5 — Invite flow                 | [ ] Not started |
| PR 6 — Hardening                   | [ ] Not started |
