# Analytics System - Developer Guide

## Overview

The analytics system is modular and extensible. You can easily:
- Change how the debug menu is triggered
- Add new KPIs to track
- Modify export formats
- Customize analysis scripts

---

## Changing the Debug Menu Trigger

The trigger mechanism is completely modular. Currently set to **triple-tap bottom-right corner**.

### Available Triggers

1. **TripleTapBottomRightTrigger** (Current) - Triple-tap invisible zone in bottom-right corner
2. **ShakeGestureTrigger** - Shake device to open menu
3. **LongPressLogoTrigger** - Long press (3s) on app logo/text

### How to Change

**In `MainTabView.swift`:**

```swift
// Current (triple-tap)
.analyticsDebug(service: analyticsService)

// Change to shake gesture
.analyticsDebug(service: analyticsService, trigger: ShakeGestureTrigger())

// Change to long press
.analyticsDebug(service: analyticsService, trigger: LongPressLogoTrigger())
```

### Creating Your Own Trigger

**1. Create a new trigger in `AnalyticsDebugTrigger.swift`:**

```swift
struct DoubleTapTopLeftTrigger: AnalyticsDebugTrigger {
    func makeTriggerView(showDebugMenu: Binding<Bool>) -> some View {
        Color.clear
            .frame(width: 100, height: 100)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                showDebugMenu.wrappedValue = true
            }
    }
}
```

**2. Use it:**

```swift
.analyticsDebug(service: analyticsService, trigger: DoubleTapTopLeftTrigger())
```

---

## Adding New KPIs

### Step-by-Step Guide

#### 1. Add Logging Method

**In `AnalyticsService+CustomEvents.swift`:**

```swift
extension AnalyticsService {
    func logShareButtonTapped(contentType: String, destination: String) {
        logEvent(
            type: "ShareButtonTapped",
            category: .engagement,  // You may need to add this category
            value: contentType,
            metadata: [
                "destination": destination,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
}
```

#### 2. Add Category (if needed)

**In `AnalyticsEvent.swift`:**

```swift
extension AnalyticsEvent {
    enum Category: String {
        case lifecycle = "Lifecycle"
        case permission = "Permission"
        case navigation = "Navigation"
        case connection = "Connection"
        case suggestion = "Suggestion"
        case invitation = "Invitation"
        case feedback = "Feedback"
        case error = "Error"
        case engagement = "Engagement"  // ← Add this
    }
}
```

#### 3. Call from Your View

```swift
Button("Share") {
    analyticsService.logShareButtonTapped(
        contentType: "suggestion",
        destination: "Messages"
    )
    // ... your share logic
}
```

#### 4. Add Summary Statistics (Optional)

**In `AnalyticsSummary.swift`**, add computation:

```swift
struct AnalyticsSummary {
    // ... existing fields
    let shareStats: ShareStats  // ← Add this
    
    struct ShareStats {
        let totalShares: Int
        let byDestination: [String: Int]
    }
}

// In generate() method:
static func generate(from events: [AnalyticsEvent], sessions: [String: [AnalyticsEvent]]) -> AnalyticsSummary {
    // ... existing code
    
    let shareStats = generateShareStats(events)  // ← Add this
    
    return AnalyticsSummary(
        // ... existing parameters
        shareStats: shareStats  // ← Add this
    )
}

private static func generateShareStats(_ events: [AnalyticsEvent]) -> ShareStats {
    let shares = events.filter { $0.eventType == "ShareButtonTapped" }
    
    var byDestination: [String: Int] = [:]
    for event in shares {
        if let dest = event.metadata?["destination"] as? String {
            byDestination[dest, default: 0] += 1
        }
    }
    
    return ShareStats(
        totalShares: shares.count,
        byDestination: byDestination
    )
}
```

#### 5. Update Python Analysis (Optional)

**In `Analytics/analyze.py`:**

```python
def analyze_shares(summary):
    """Analyze share button usage."""
    print_header("🔗 SHARING")
    
    if summary and 'shareStats' in summary:
        shares = summary['shareStats']
        print(f"Total shares: {shares['totalShares']}")
        
        print(f"\nBy destination:")
        for dest, count in shares['byDestination'].items():
            print(f"  {dest}: {count}")
    else:
        print("No share data available")

# In main():
analyze_shares(summary)
```

---

## Session Management

### How Sessions Work

**Automatic:**
- Each app launch = new session
- Session ID = `Session_YYYY-MM-DD_HH-MM-SS`
- No manual intervention needed

**What Persists:**
- All tracked contacts
- All analytics events (across all sessions)
- All user data

**What Changes:**
- Session ID (new one per launch)

### Testing Workflow

One session per install — delete the app between users so each user starts fresh (clean contacts, new session ID, permission prompts reset).

```
User 1: Install app → Session_2026-04-23_14-30-00
        Use app
        Triple-tap → Export → Save file → Delete app

User 2: Reinstall app → Session_2026-04-23_14-45-00 (fresh data)
        Use app
        Triple-tap → Export → Save file → Delete app

Result: Each user's data is clean; drop all files into analytics/Data/ to combine
```

---

## Export System

### What Gets Exported

Three files per export:

1. **`eta_analytics_YYYY-MM-DD_HH-MM-SS.csv`**
   - Raw event log
   - Good for: Excel, manual inspection

2. **`eta_analytics_YYYY-MM-DD_HH-MM-SS.json`**
   - Structured session data
   - Good for: Python scripts, programmatic analysis

3. **`eta_summary_YYYY-MM-DD_HH-MM-SS.json`**
   - Pre-computed statistics
   - Good for: Instant insights, wiki tables

### Files Accumulate

Exports never overwrite - each gets unique timestamp:

```
Data/
  eta_analytics_2026-04-23_14-30-00.csv  ← Export #1
  eta_analytics_2026-04-23_14-30-00.json
  eta_summary_2026-04-23_14-30-00.json
  
  eta_analytics_2026-04-23_15-45-00.csv  ← Export #2
  eta_analytics_2026-04-23_15-45-00.json
  eta_summary_2026-04-23_15-45-00.json
```

### Changing Export Format

**In `AnalyticsService.swift`, modify:**

```swift
func createExportFiles() -> [URL] {
    let timestamp = Self.generateSessionIdentifier()
    let tempDir = FileManager.default.temporaryDirectory
    
    var files: [URL] = []
    
    // Add your custom format here
    let xmlURL = tempDir.appendingPathComponent("eta_analytics_\(timestamp).xml")
    if let xmlData = exportAsXML().data(using: .utf8) {
        try? xmlData.write(to: xmlURL)
        files.append(xmlURL)
    }
    
    // ... existing CSV, JSON, summary
    
    return files
}

// Add your export function
func exportAsXML() -> String {
    // Your XML generation logic
}
```

---

## File Organization

```
/Eta
  /Analytics/                    ← Python analysis tools
    analyze.py
    visualize.py
    query.py
    README.md
    /Data/                      ← Export destination
      .gitkeep
    .gitignore
  
  /Models/                       ← (Existing) SwiftData models
    TrackedContact.swift
    AnalyticsEvent.swift
  
  /Services/                     ← (Existing) Business logic
    RelationshipService.swift
    SuggestionService.swift
    AnalyticsService.swift
    AnalyticsService+CustomEvents.swift
  
  /ViewModels/                   ← (Existing) View models
    ConnectionsViewModel.swift
    SuggestionViewModel.swift
  
  /Views/                        ← (Existing) UI
    MainTabView.swift
    ConnectionsView.swift
    SuggestionView.swift
    AnalyticsDebugOverlay.swift
  
  /Utilities/                    ← (Existing) Helpers
    AnalyticsDebugModifier.swift
    AnalyticsDebugTrigger.swift
    ScreenTrackingModifier.swift
    AnalyticsSummary.swift
```

**Note:** The actual file structure in Xcode may be flat - this is the logical organization. You can organize into groups in Xcode without moving files on disk.

---

## Code Style Guidelines

### Matching Existing Codebase

The analytics system follows your codebase's patterns:

1. **Documentation Comments**
   - Use `///` for public APIs
   - Explain "why" not just "what"
   - Include usage examples

2. **MARK Comments**
   - Organize code into logical sections
   - Use `// MARK: - Section Name`

3. **Naming Conventions**
   - Services: `AnalyticsService`, `RelationshipService`
   - Events: `logPermissionGranted`, `logScreenViewed`
   - View Modifiers: `.analyticsDebug()`, `.trackScreen()`

4. **Protocol-Oriented**
   - `AnalyticsDebugTrigger` protocol for flexibility
   - Easy to swap implementations

5. **Dependency Injection**
   - Services passed through initializers
   - No singletons or globals

---

## Common Customizations

### 1. Change Screen Time Tracking

Currently auto-tracks via `.trackScreen()` modifier. To disable for specific screens:

```swift
// Don't add .trackScreen() modifier
ConnectionsView(viewModel: viewModel, analyticsService: analytics)
// No automatic tracking
```

### 2. Add Manual Time Tracking

```swift
let startTime = Date()
// ... user does something
let duration = Date().timeIntervalSince(startTime)

analyticsService.logEvent(
    type: "TaskCompleted",
    category: .engagement,
    metadata: ["duration": duration]
)
```

### 3. Batch Export Multiple Sessions

If you have multiple export files, use Python:

```python
import pandas as pd
from pathlib import Path

# Load all CSV files
all_data = []
for csv_file in Path("Data").glob("eta_analytics_*.csv"):
    df = pd.read_csv(csv_file)
    all_data.append(df)

combined = pd.concat(all_data, ignore_index=True)
combined.to_csv("Data/combined_all_sessions.csv", index=False)
```

### 4. Add Real-Time Debug Logging

```swift
func logEvent(type: String, category: Category, value: String? = nil, metadata: [String: Any]? = nil) {
    let event = AnalyticsEvent(...)
    modelContext.insert(event)
    
    #if DEBUG
    print("📊 [\(category.rawValue)] \(type): \(value ?? "")")
    #endif
}
```

---

## Testing Tips

### Verify Analytics in Debug

Add this to any view:

```swift
.task {
    // Log all events in console
    let events = analyticsService.fetchAllEvents()
    for event in events {
        print("\(event.sessionID) | \(event.eventType)")
    }
}
```

### Quick Event Count

```swift
print("Total events: \(analyticsService.fetchAllEvents().count)")
```

### Inspect Live Data

Use Xcode's SwiftData inspector or add a debug button:

```swift
Button("Print Analytics") {
    let events = analyticsService.fetchAllEvents()
    print("=== ANALYTICS DEBUG ===")
    for event in events {
        print("\(event.timestamp) | \(event.eventType) | \(event.value ?? "")")
    }
}
```

---

## Questions?

- **Trigger not working?** Make sure you're in DEBUG build
- **Events not saving?** Check SwiftData container configuration
- **Python errors?** Run `pip3 install pandas matplotlib`
- **Need more help?** Check the inline comments in each file

---

**The system is designed to be extended - don't be afraid to customize it!**
