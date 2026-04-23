# Eta — Architecture Guide for Claude

This file is the authoritative reference for code generation in this repo.
Read it before writing any new file. Follow it strictly unless the user explicitly overrides a decision here.

---

## What Eta is

A lightweight iOS app that helps users maintain friendships by reducing friction around
scheduling in-person hangouts. The core loop:

**Analyze relationship data → surface a smart suggestion → make it easy to send an invite.**

MVP data source: Apple Calendar (implicit signals only).
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
 ├─ CalendarDataProvider()
 ├─ RelationshipService(providers: [CalendarDataProvider], repository: ContactRepository)
 ├─ RulesSuggestionStrategy()
 ├─ SuggestionService(relationship: RelationshipService, strategy: RulesSuggestionStrategy)
 ├─ iMessageInviteProvider()
 ├─ InviteService(provider: iMessageInviteProvider)
 ├─ SuggestionViewModel(suggestion: SuggestionService, invite: InviteService)
 └─ ConnectionsViewModel(repository: ContactRepository)
```

ViewModels are created in `EtaApp` and passed into views as constructor arguments
or via `.environment()` if needed across the tab hierarchy.

---

## Data models

### `TrackedContact` (`@Model` — persisted)

```swift
@Model class TrackedContact {
    var id: UUID
    var cnContactIdentifier: String   // CNContact.identifier — for re-sync
    var name: String                  // Copied at add time — readable without Contacts permission
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
    var participantEmails: [String]   // Matched against TrackedContact.emailAddress
}
```

### `RelationshipHealth` (value type)

```swift
struct RelationshipHealth {
    var contact: TrackedContact
    var lastHangoutDate: Date?
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

1. `SuggestionViewModel` calls `SuggestionService.generateSuggestion()` on:
   - App foreground (via `scenePhase` observation in the ViewModel)
   - Explicit user pull-to-refresh
2. `SuggestionService` calls `RelationshipService.computeHealth()` which fans out to all `ImplicitDataProvider`s
3. Result flows back to `SuggestionViewModel` and updates the view

---

## Calendar event → hangout matching

`CalendarDataProvider` counts an event as a hangout with a `TrackedContact` when:
- The event has at least one attendee whose email matches `TrackedContact.emailAddress` (case-insensitive)
- The event is not an all-day event (all-day events are likely non-personal)
- The event duration is ≥ 15 minutes

Events with no attendee data are ignored — no fuzzy title matching.

---

## What is intentionally NOT abstracted (yet)

- `ContactRepository` — SwiftData is stable; no repository protocol needed now
- Relationship scoring formula — lives as a private method inside `RelationshipService`; extract to a `RelationshipScorer` protocol only if the formula needs to vary per user or be swapped
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
