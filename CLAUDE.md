# Eta — Architecture Guide for Claude

This file is the authoritative reference for code generation in this repo.
Read it before writing any new file. Follow it strictly unless the user explicitly overrides a decision here.

---

## What Eta is

A lightweight iOS app that helps users maintain friendships by reducing friction around
scheduling in-person hangouts. The core loop:

**Detect a free slot + identify an overdue friend → surface a time-specific suggestion → make it easy to send an invite.**

A suggestion requires both signals simultaneously: a gap in the user's near-term calendar
AND a contact whose relationship health score exceeds a recency threshold. Either signal
alone produces no suggestion — the inbox stays empty.

MVP data source: Apple Calendar (implicit signals only — past events for health, upcoming gaps for opportunity).
MVP suggestion engine: rules-based (not ML).
MVP invite mechanism: pre-filled iMessage via URL scheme.

---

## Platform & tooling

- **iOS 26+, Swift 5.0, SwiftUI**
- **SwiftData** for persistence — use `@Model` for all persisted types
- **@Observable** for all ViewModels — do NOT use `ObservableObject` or `@Published`
- **EventKit** for Calendar access
- **Contacts framework** (`CNContactStore`) for the contacts picker
- No third-party dependencies
- No backend — fully on-device for MVP

---

## Architectural layers

```
Views  →  ViewModels  →  Services  →  Protocols  ←  Concrete Implementations
                                   ↓
                             Repositories  →  SwiftData (ModelContext)
                                   ↓
                                Models
```

Dependencies only flow downward. A View never touches a Service directly.
A Service never touches SwiftData directly — it goes through a Repository.

---

## Folder structure

Every new file must go in the correct folder. Do not create new top-level folders
without a clear reason.

```
Eta/
├── App/
│   ├── EtaApp.swift              # ModelContainer setup + dependency wiring
│   └── MainTabView.swift         # Root TabView — "For You" | "Friends"
│
├── Models/
│   ├── TrackedContact.swift      # @Model — SwiftData persisted contact
│   ├── HangoutEvent.swift        # Value type — parsed calendar event
│   ├── RelationshipHealth.swift  # Value type — computed score + metadata per contact
│   ├── Suggestion.swift          # Value type — friend + activity + reason string
│   └── Activity.swift            # enum — hardcoded pool for MVP
│
├── Protocols/
│   ├── ImplicitDataProvider.swift
│   ├── SuggestionStrategy.swift
│   └── InviteProvider.swift
│
├── Formatters/
│   └── ContactFormatter.swift           # Locale-aware name formatting via CNContactFormatter
│
├── DataProviders/
│   └── CalendarDataProvider.swift   # Concrete ImplicitDataProvider — EKEventStore
│
├── Strategies/
│   └── RulesSuggestionStrategy.swift  # Concrete SuggestionStrategy — sorts by health score
│
├── InviteProviders/
│   └── iMessageInviteProvider.swift   # Concrete InviteProvider — iMessage URL scheme
│
├── Repositories/
│   └── ContactRepository.swift        # SwiftData CRUD for TrackedContact
│
├── Services/
│   ├── RelationshipService.swift      # [ImplicitDataProvider] + contacts → [RelationshipHealth]
│   ├── SuggestionService.swift        # RelationshipService + SuggestionStrategy → Suggestion
│   └── InviteService.swift            # Wraps InviteProvider; formats the invite message text
│
├── ViewModels/
│   ├── SuggestionViewModel.swift      # Drives SuggestionView
│   └── ConnectionsViewModel.swift     # Drives ConnectionsView
│
└── Views/
    ├── Suggestion/
    │   ├── SuggestionView.swift
    │   └── SuggestionCard.swift
    └── Connections/
        ├── ConnectionsView.swift
        └── AddConnectionSheet.swift
```

---

## The three protocol boundaries (volatile seams)

Only these three things are abstracted behind protocols, because they are explicitly
expected to change. Do not add protocol boundaries speculatively.

### 1. `ImplicitDataProvider`

Anything that can supply raw hangout events. Calendar today; social APIs later.

```swift
protocol ImplicitDataProvider {
    /// Returns events involving any of the given contacts, on or after `since`.
    func fetchEvents(for contacts: [TrackedContact], since date: Date) async throws -> [HangoutEvent]
    /// Returns true if access was granted.
    func requestAccess() async -> Bool
}
```

Concrete: `CalendarDataProvider`

`RelationshipService` holds `[any ImplicitDataProvider]` so multiple providers can coexist.

### 2. `SuggestionStrategy`

How we turn a ranked list of health scores into a single suggestion. Rules today; ML later.

```swift
protocol SuggestionStrategy {
    func suggest(from healthScores: [RelationshipHealth]) -> Suggestion?
}
```

Concrete: `RulesSuggestionStrategy`

### 3. `InviteProvider`

How we deliver the invite. iMessage URL scheme today; iMessage extension later.

```swift
protocol InviteProvider {
    func sendInvite(for suggestion: Suggestion)
}
```

Concrete: `iMessageInviteProvider`

---

## Dependency wiring

All concrete types are instantiated **once**, in `EtaApp.swift`, and injected
downward via constructors. No singletons. No environment objects for services.

```
EtaApp
 ├─ ContactRepository(modelContext:)
 ├─ ContactFormatter()
 ├─ CalendarDataProvider()
 ├─ RelationshipService(providers: [CalendarDataProvider], repository: ContactRepository)
 ├─ RulesSuggestionStrategy()
 ├─ SuggestionService(calendar: CalendarDataProvider, relationship: RelationshipService, strategy: RulesSuggestionStrategy)
 ├─ iMessageInviteProvider()
 ├─ InviteService(provider: iMessageInviteProvider)
 ├─ SuggestionViewModel(suggestionService: SuggestionService, inviteService: InviteService, formatter: ContactFormatter)
 └─ ConnectionsViewModel(repository: ContactRepository, formatter: ContactFormatter, relationshipService: RelationshipService)
```

`CalendarDataProvider` is injected into both `RelationshipService` (as an `ImplicitDataProvider` for historical event fetching) and `SuggestionService` (concretely, for free slot detection). A single instance is shared between both.

ViewModels are created in `EtaApp` and passed into views as constructor arguments
or via `.environment()` if needed across the tab hierarchy.

---

## Data models

### `TrackedContact` (`@Model` — persisted)

```swift
@Model class TrackedContact {
    var id: UUID
    var cnContactIdentifier: String   // CNContact.identifier — for re-sync
    var name: String                  // Pre-formatted fallback — readable without Contacts permission
    var givenName: String             // Raw component — used by ContactFormatter
    var familyName: String            // Raw component — used by ContactFormatter
    var phoneNumber: String?          // Copied at add time
    var emailAddress: String?         // Copied at add time — used for calendar attendee matching
    var isActive: Bool                // Whether included in suggestion pool
    var addedAt: Date
}
```

### `HangoutEvent` (value type)

```swift
struct HangoutEvent {
    var eventIdentifier: String
    var title: String
    var startDate: Date
    var endDate: Date
    // One ContactMatcher per attendee — each encapsulates a value and a matching rule.
    // See ContactMatcher enum (defined alongside HangoutEvent) for .email and .name cases.
    var participantMatchers: [ContactMatcher]
}
```

### `RelationshipHealth` (value type)

```swift
struct RelationshipHealth {
    var contact: TrackedContact
    var lastHangoutDate: Date?
    var lastHangoutTitle: String?     // Title of most recent event — used for personalised labels
    var hangoutCount: Int             // In the look-back window (default: 90 days)
    var score: Double                 // Higher = more overdue. Used for ranking.
}
```

### `Suggestion` (value type)

```swift
struct Suggestion {
    var contact: TrackedContact
    var activity: Activity
    var reason: String                // Human-readable, e.g. "You haven't hung out in 3 weeks"
    var proposedTime: DateInterval    // The specific free slot that triggered this suggestion
    var generatedAt: Date
}
```

### `Activity` (enum — hardcoded for MVP)

```swift
enum Activity: String, CaseIterable {
    case walk         = "Go for a walk"
    case coffee       = "Grab coffee"
    case groceryRun   = "Do a grocery run"
    case lunch        = "Get lunch"
    case workout      = "Work out together"
    case studySession = "Study together"
}
```

---

## Naming conventions

| What | Convention | Example |
|---|---|---|
| Protocols | Noun describing role | `ImplicitDataProvider`, `SuggestionStrategy` |
| Protocol implementations | ConcreteSource + Protocol noun | `CalendarDataProvider`, `RulesSuggestionStrategy` |
| Services | NounService | `RelationshipService`, `InviteService` |
| Repositories | NounRepository | `ContactRepository` |
| ViewModels | NounViewModel | `SuggestionViewModel` |
| Views | NounView / NounSheet / NounCard | `SuggestionCard`, `AddConnectionSheet` |
| **Never use** | `...Manager`, `...Helper`, `...Util` | — |

---

## Permissions model

Permissions are requested **inline** at first use — no dedicated onboarding flow.

- **Contacts**: requested when the user taps "Add Friend" in ConnectionsView
- **Calendar**: requested inside `CalendarDataProvider.requestAccess()` when `RelationshipService` runs for the first time

Both permission requests must be preceded by a brief in-context explanation
(a line of text in the UI, not a separate screen).

---

## Navigation

- Root: `MainTabView` — two tabs, "For You" (SuggestionView) and "Friends" (ConnectionsView)
- No custom router or coordinator — use SwiftUI `NavigationStack` inside each tab
- Sheets: `AddConnectionSheet` presented from ConnectionsView

---

## Suggestion lifecycle

1. `SuggestionViewModel.refresh()` is called on:
   - Initial load (`.task` in `SuggestionView`)
   - App foreground — `SuggestionView` observes `@Environment(\.scenePhase)` and calls `refresh()` when the scene becomes `.active`. Scene phase is observed in the View, not the ViewModel, so the ViewModel stays free of SwiftUI and UIKit imports.
   - Explicit user pull-to-refresh
2. `SuggestionService.generateSuggestion()` checks **both signals** in order:
   a. Calls `CalendarDataProvider.findFreeSlot(within: 3)` — looks up to 3 days ahead for a gap ≥ 1 hour during 9am–9pm. If none → returns nil immediately.
   b. Calls `RelationshipService.computeHealth()` to get ranked health scores.
   c. Calls `strategy.suggest(from: healthScores)` — the strategy returns nil if no contact exceeds the recency threshold (score < 7, i.e. seen within the last week). If nil → returns nil.
   d. Attaches `proposedTime` from step (a) to the strategy's result and returns the complete `Suggestion`.
3. Result (or nil) flows back to `SuggestionViewModel` — view renders the card or the empty inbox state.
4. User taps **"Maybe Later"** → `SuggestionViewModel.dismiss()` sets `suggestion = nil`. Nothing is persisted; the next `refresh()` recomputes from scratch.

---

## Calendar event → hangout matching

`CalendarDataProvider` counts an event as a hangout with a `TrackedContact` when:
- The event is not an all-day event (all-day events are likely non-personal)
- The event duration is ≥ 15 minutes
- At least one attendee is identified as a tracked contact via `ContactMatcher`

`ContactMatcher` tries two signals per attendee, in order:
1. **Email** — extracted from `EKParticipant.url` (`mailto:` prefix stripped, lowercased). Matched against `TrackedContact.emailAddress`.
2. **Name** — `EKParticipant.name` lowercased, matched against `"\(givenName) \(familyName)"` constructed in given-first order (not `contact.name`, which may be locale-formatted). `EKParticipant` does not expose phone numbers, so name is the only fallback.

Events with no attendee data are ignored. The current user and declined attendees are excluded from matcher construction.

## Free slot detection

`CalendarDataProvider.findFreeSlot(within:minimumDuration:)` finds the earliest gap in the user's calendar suitable for a hangout:
- Searches each day from now up to `lookAheadDays` (default 3)
- Search window per day: 9am–9pm
- Minimum gap duration: 1 hour (configurable via `minimumDuration` parameter)
- Returns the first qualifying `DateInterval`, or nil if none found

This method is **not** on the `ImplicitDataProvider` protocol — free slot detection is a distinct capability from historical event fetching, and no other data source is expected to provide it. `SuggestionService` depends on `CalendarDataProvider` concretely for this method.

---

## Name formatting

Contact names must be formatted using `ContactFormatter` — never call `CNContactFormatter` directly in a View or ViewModel.

- `TrackedContact` stores `givenName` and `familyName` as raw components, plus a pre-formatted `name` string as a fallback.
- `ContactFormatter` is the **only** type that imports `Contacts` for display purposes. It builds a `CNMutableContact` from those components and calls `CNContactFormatter.string(from:style:)`.
- ViewModels receive a `ContactFormatter` via constructor injection and expose plain `String` values to Views.
- `ContactFormatter` does **not** need a protocol yet. If a user-facing name-style preference is added, extract a protocol at that point.

```swift
// Correct — in a ViewModel
let displayName = formatter.displayName(for: contact)

// Wrong — never do this in a View or ViewModel
CNContactFormatter.string(from: cnContact, style: .fullName)
```

---

## What is intentionally NOT abstracted (yet)

- `ContactRepository` — SwiftData is stable; no repository protocol needed now
- Relationship scoring formula — lives as a private method inside `RelationshipService`; extract to a `RelationshipScorer` protocol only if the formula needs to vary per user or be swapped
- Free slot detection — `CalendarDataProvider.findFreeSlot` is a concrete method, not behind a protocol. If a second calendar source (e.g. Google Calendar) ever needs to contribute free-slot data, extract a `FreeTimeProvider` protocol at that point.
- Navigation routing — NavigationStack in-view is sufficient at this scale
- Dependency injection container — constructor injection is explicit enough for a team of 5

---

## Open decisions (resolve before implementing the affected feature)

| Decision | Options | Notes |
|---|---|---|
| `Activity` pool content | Hardcoded enum vs. user-customizable list | Hardcoded for MVP; make user-editable in v2 |
| Suggestion history | Store past suggestions in SwiftData vs. ephemeral | Not needed for MVP |
| Explicit signals (like/dislike feedback) | Not in MVP | Design the data model before adding so it fits TrackedContact cleanly |
| Social API providers | Not in MVP | Any new source just conforms to `ImplicitDataProvider` |

---

## Code generation rules for Claude

1. **Read this file before writing any new file.**
2. Place every new file in its designated folder per the structure above.
3. Never introduce a new protocol boundary without flagging it to the user and explaining what volatility it isolates.
4. Never use `Manager`, `Helper`, or `Util` in a type name.
5. Never use `ObservableObject` or `@Published` — use `@Observable`.
6. Never access `ModelContext` outside of a Repository.
7. Services receive their dependencies via constructor injection — never use singletons or static state.
8. Permissions are always requested inline; never build a separate onboarding screen unless the user asks.
9. Keep the `Activity` enum hardcoded until the user explicitly asks for dynamic activities.
10. When in doubt about scope, do less and ask — this is an MVP.
11. Never call `CNContactFormatter` directly in a View or ViewModel — always go through `ContactFormatter.displayName(for:)`.
12. Scene phase is observed in Views via `@Environment(\.scenePhase)`, not in ViewModels. ViewModels expose a plain `refresh() async` method; the View calls it from `.onChange(of: scenePhase)`.
