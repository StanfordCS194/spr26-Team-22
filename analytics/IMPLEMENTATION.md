# Analytics System Implementation Summary

## Overview

A comprehensive analytics system has been added to the Eta app to track user behavior during MVP testing. The system captures **all KPIs** discussed, exports data in multiple formats, and includes Python analysis tools.

## What's Been Added

### Core Analytics Files

1. **`AnalyticsEvent.swift`** - SwiftData model for storing events
2. **`AnalyticsService.swift`** - Central logging service with all KPI tracking
3. **`AnalyticsSummary.swift`** - Pre-computed statistics generator
4. **`AnalyticsDebugOverlay.swift`** - Debug UI for exporting data
5. **`AnalyticsDebugModifier.swift`** - Triple-tap gesture handler
6. **`ScreenTrackingModifier.swift`** - Automatic screen time tracking

### Analysis Tools (`/Analytics` folder)

1. **`analyze.py`** - Summary statistics script
2. **`visualize.py`** - Chart generation script
3. **`query.py`** - Interactive query tool
4. **`README.md`** - Complete documentation
5. **`Data/`** - Folder for exported analytics files

### Updated Files

- **`EtaApp.swift`** - Integrated analytics service, lifecycle tracking
- **`MainTabView.swift`** - Added triple-tap debug gesture
- **`ConnectionsView.swift`** - Added screen tracking, button tracking, friend deletion tracking
- **`AddConnectionSheet.swift`** - Permission tracking, connection tracking (`isInitialAdd` flag)
- **`SuggestionView.swift`** - Suggestion tracking, "Maybe Later" dismissal tracking
- **`SuggestionCard.swift`** - Interaction tracking
- **`RelationshipService.swift`** - Calendar permission tracking

## How to Use During Testing

### Setup (One Time)

1. Build and run the app in DEBUG mode on your iPhone
2. No additional setup needed - analytics are automatic

### During Testing

1. **Hand phone to test user** - App tracks everything automatically
2. **User tests the app** - All interactions are logged
3. **Between users:** triple-tap → Export → delete app → reinstall

### After All Testing

1. **Export data:**
   - Triple-tap bottom-right corner
   - Tap "Export Analytics Data"
   - AirDrop to your Mac (or save to Files app)

2. **Analyze data:**
   ```bash
   cd analytics
   python3 analyze.py      # View statistics
   python3 visualize.py    # Generate charts
   python3 query.py        # Explore data interactively
   ```

3. **Build wiki tables:**
   - Copy stats from `analyze.py` output
   - Embed charts from `visualize.py` (saved as PNG)
   - Reference specific sessions with `query.py`

## All Tracked KPIs

### 📱 Permissions
- ✅ Calendar permission requested/granted/denied
- ✅ Time to grant calendar permission
- ✅ Contacts permission requested/granted/denied
- ✅ Time to grant contacts permission
- ✅ Selection type (all vs selected contacts)

### 🚀 Onboarding
- ✅ Total onboarding duration (app launch to main screen)
- ✅ Completion rate

### 👥 Connections
- ✅ Number of connections added (total and per user)
- ✅ Total contacts available
- ✅ Percentage of available contacts added
- ✅ Connections edited after adding
- ✅ "Show Selected" button clicks
- ✅ Time spent adding connections

### ✨ Suggestions
- ✅ Number of suggestions generated
- ✅ Suggestions viewed
- ✅ Suggestions tapped/interacted with
- ✅ Tap rate (% of viewed suggestions that were tapped)
- ✅ Average suggestions per session
- ✅ Days since last hangout for suggested contacts

### 📨 Invitations (Ready for when feature is implemented)
- ✅ Invitations initiated
- ✅ Invitations completed (sent)
- ✅ Invitations abandoned
- ✅ Time to send invitation
- ✅ Completion rate
- ✅ User responses (yes/maybe/no)
- ✅ Activity types chosen
- ✅ Time of day preferences (morning/afternoon/evening)
- ✅ Free slot suggested (yes/no)
- ✅ Free slot accepted (yes/no)

### ⏱️ Navigation & Screen Time
- ✅ Time spent on each screen
- ✅ Screen view/exit events
- ✅ Button tap sequences
- ✅ Navigation paths to invitation
- ✅ App backgrounded/foregrounded events

### 🔄 Session Management
- ✅ Unique session ID per app launch
- ✅ Session start/end times
- ✅ Total events per session
- ✅ Session duration

## Export Formats

### 1. CSV (`eta_analytics_YYYY-MM-DD_HH-MM-SS.csv`)
```csv
SessionID,Timestamp,EventType,Category,Value,Metadata
Session_2026-04-23_14-30-00,2026-04-23T14:30:15Z,AppLaunched,Lifecycle,,{}
Session_2026-04-23_14-30-00,2026-04-23T14:30:18Z,PermissionRequested,Permission,Calendar,{}
```

**Good for:** Excel, manual inspection, copy-paste to wiki

### 2. JSON (`eta_analytics_YYYY-MM-DD_HH-MM-SS.json`)
```json
{
  "exportDate": "2026-04-23T18:00:00Z",
  "totalSessions": 5,
  "totalEvents": 347,
  "sessions": [...]
}
```

**Good for:** Python scripts, programmatic analysis

### 3. Summary Stats (`eta_summary_YYYY-MM-DD_HH-MM-SS.json`)
```json
{
  "summary": {
    "totalSessions": 5,
    "totalUsers": 5
  },
  "permissions": {
    "calendar": {
      "grantRate": 100.0,
      "avgTimeToGrant": 4.2
    }
  },
  "invitations": {
    "completionRate": 87.5,
    "avgTimeToSend": 42.3
  }
}
```

**Good for:** Instant insights, copy-paste stats to wiki

## Example Analysis Outputs

### From `analyze.py`:
```
📱 PERMISSIONS
Calendar Access:
  Requested: 5
  Granted: 5 (100.0%)
  Avg time to grant: 4.2s

👥 CONNECTIONS
Total connections added: 23
Average per user: 4.6
Average % of contacts added: 3.1%

📨 INVITATIONS
Initiated: 8
Completed: 7 (87.5%)
Average time to send: 42.3s
```

### From `visualize.py`:
- `permission_funnel.png` - Permission grant visualization
- `invitation_funnel.png` - Conversion funnel chart
- `screen_time.png` - Time spent per screen
- `activity_breakdown.png` - Pie chart of activities
- `time_of_day.png` - Time preference bar chart
- `response_breakdown.png` - Yes/maybe/no distribution

### From `query.py`:
```
eta> sessions
  List all user sessions with event counts

eta> user Session_001
  Show all events for that specific session

eta> type Permission
  Show all permission-related events

eta> invitations
  Show all invitation events
```

## Privacy & Data Management

### What's Tracked
- Session IDs (timestamps)
- Event types and timing
- Contact names (only those you add to the app)
- Screen names and durations
- User interactions (buttons, taps, etc.)

### What's NOT Tracked
- Full contact database
- Calendar event details beyond what's needed
- Any personal data not shown in the app UI

### Data Storage
- **During testing:** SwiftData (local on device)
- **After export:** Files you choose (AirDrop, Files app, etc.)
- **In repository:** Add `Data/` to `.gitignore` to protect user data

## Troubleshooting

### "No analytics data found"
- Make sure you've exported data from the app first
- Check that files are in `Analytics/Data/` folder
- Files should be named `eta_analytics_*.csv`, etc.

### Triple-tap not working
- Only works in DEBUG builds (not Release)
- Tap quickly in bottom-right corner (80x80 point area)
- Try tapping slightly higher or to the left if needed

### Python scripts not running
```bash
# Install dependencies
pip3 install pandas matplotlib

# Make scripts executable (optional)
chmod +x analyze.py visualize.py query.py
```

### Analytics not showing up
- Make sure you've used the app enough to generate events
- Check that the DEBUG build is running (not Release)

## For Your Wiki Deliverable

### Tables to Include

1. **Permission Grant Rates**
   | Permission Type | Requested | Granted | Grant Rate | Avg Time (s) |
   |----------------|-----------|---------|------------|--------------|
   | Calendar       | 5         | 5       | 100%       | 4.2          |
   | Contacts       | 5         | 4       | 80%        | 5.8          |

2. **Connection Behavior**
   | Metric                    | Value |
   |---------------------------|-------|
   | Total Connections Added   | 23    |
   | Avg per User              | 4.6   |
   | Avg % of Contacts Added   | 3.1%  |
   | Connections Edited        | 5     |

3. **Suggestion Engagement**
   | Metric                | Value |
   |-----------------------|-------|
   | Suggestions Generated | 18    |
   | Viewed                | 18    |
   | Tapped                | 12    |
   | Tap Rate              | 66.7% |

4. **Invitation Funnel**
   | Stage      | Count | Conversion |
   |------------|-------|------------|
   | Initiated  | 8     | 100%       |
   | Completed  | 7     | 87.5%      |
   | Yes Response | 5   | 62.5%      |

### Charts to Include
- Permission funnel visualization
- Invitation conversion funnel
- Screen time breakdown
- Activity preferences
- Time of day distribution

### Qualitative Observations
Use `query.py` to find:
- Specific user journeys (screen sequences)
- Common pain points (abandoned flows)
- Successful patterns (fast completions)

## Technical Details

### Architecture
- **Storage:** SwiftData (persists across app launches)
- **Logging:** Synchronous writes to both SwiftData and backup CSV
- **Export:** Multiple formats generated on-demand
- **Session:** UUID-based, generated on app launch

### Performance
- Minimal overhead (milliseconds per event)
- Backup CSV appends are non-blocking
- All analytics run on main thread (intentional for testing)

### Future Enhancements
When you add remote backend (Supabase/Firebase):
- Network sync layer in `AnalyticsService`
- Real-time dashboard
- Cross-device aggregation
- A/B testing infrastructure

## Questions?

- Check `/Analytics/README.md` for detailed usage
- View `AnalyticsService.swift` for all tracked events
- See individual Python scripts for analysis examples

---

**Built for Eta MVP Testing - April 2026**
