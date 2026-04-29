# Eta Analytics

This folder contains tools for analyzing data collected during user testing sessions.

## Quick Start

### 1. Export Data from App

During testing:
- **Triple-tap the bottom-right corner** of the app (only works in DEBUG builds)
- Tap **"Export Analytics Data"**
- Use **AirDrop** to send files to your Mac, or save to Files app
- Place the exported files in the `analytics/Data/` folder

The app exports three files per export:
- `eta_analytics_YYYY-MM-DD_HH-MM-SS.csv` - Raw event data
- `eta_analytics_YYYY-MM-DD_HH-MM-SS.json` - Structured session data
- `eta_summary_YYYY-MM-DD_HH-MM-SS.json` - Pre-computed statistics

### 2. Run Analysis Scripts

```bash
cd analytics

# View summary statistics
python3 analyze.py

# Generate charts and visualizations
python3 visualize.py

# Interactive data exploration
python3 query.py
```

## Requirements

Install Python dependencies:

```bash
pip3 install pandas matplotlib
```

## Files

- **`analyze.py`** - Displays summary statistics and key metrics
- **`visualize.py`** - Generates charts (saved as PNG files in Data/)
- **`query.py`** - Interactive command-line tool for exploring data
- **`Data/`** - Place exported analytics files here

## Testing Flow

**One session per app install.** Delete and reinstall the app between users so each user starts fresh — clean permission prompts, clean contacts list, new session ID.

1. Install the app on your phone
2. Hand phone to user — they open the app fresh
3. User tests the app
4. **After the session:** triple-tap bottom-right → **Export** → AirDrop to your Mac
5. Delete app from phone, reinstall for next user
6. Repeat for each user
7. Drop all exported files into `analytics/Data/` → `python3 analyze.py`

### Combining data across teammates

Each exported file contains all sessions recorded since the last install. When multiple teammates each test with different users, drop everyone's export files into `Data/` together — the scripts load the most recently modified file, which should be the one with the most sessions. If you have exports from multiple phones, **merge them manually** by copying the sessions into one JSON, or just run `analyze.py` once per export file and compare the outputs.

Sessions are identified by the unique ID generated on each app launch (`Session_YYYY-MM-DD_HH-MM-SS`), so there are no ID collisions across devices.

## Example Usage

### Analyze All Data

```bash
python3 analyze.py
```

Output includes:
- Permission grant rates and timing
- Onboarding completion rate and time (app launch → first friend added)
- Connection management stats
- Suggestion engagement rates
- Invitation conversion funnel
- Screen time breakdown
- Per-session details

### Generate Visualizations

```bash
python3 visualize.py
```

Creates:
- `Data/permission_funnel.png` - Calendar & contacts permission rates
- `Data/invitation_funnel.png` - Invitation conversion stages
- `Data/screen_time.png` - Time spent on each screen
- `Data/activity_breakdown.png` - Activity type distribution
- `Data/time_of_day.png` - Invitation time preferences
- `Data/response_breakdown.png` - Yes/Maybe/No distribution

### Interactive Queries

```bash
python3 query.py
```

Available commands:
- `sessions` - List all user sessions
- `user <id>` - Show events for a specific session
- `type <event>` - Filter by event type
- `permissions` - Show all permission events
- `invitations` - Show all invitation events
- `stats` - Quick statistics
- `help` - Show all commands

Example queries:
```
eta> sessions
eta> user Session_2026-04-23_14-30-00
eta> type Permission
eta> permissions
eta> invitations
eta> stats
```

## KPIs Tracked

### Permissions
- **Grant rate** (calendar + contacts): Did users allow access, or bail?
- **Time to grant**: How long did they hesitate before tapping Allow? High hesitation = trust issue with the permission copy.
- **Contacts selection type** (all vs. selected): Tells you whether users are cautious about sharing their full address book.

### Onboarding
- **Completion rate**: % of sessions where the user added at least one friend. If this is low, the permission + add-friends flow has too much friction.
- **Duration**: Time from app launch to first friend added. Longer = more friction in the add flow.
- "Onboarding" in Eta = getting through the contacts permission + adding your first friend. There is no separate onboarding screen.

### Connections
- **Avg friends added per user**: Core adoption metric — are users actually populating their list?
- **% of address book added** (`avgPercentageAdded`): What fraction of their contacts did they bring into Eta? Low % may mean the picker UI is too slow to scroll, or they only added a few manually.
  - Computed from the *final* `ConnectionAdded` event per session, so it reflects where the user stopped, not an average mid-add.
  - `isInitialAdd: true` = added from the picker in the first pass; `isInitialAdd: false` = went back and added more.
- **Removed**: Did any users delete a friend? High removal rate suggests the add flow is too easy to accidentally add someone.
- **Edit rate**: Did users update friend info after adding? Signals whether the auto-populated data (name, phone) was wrong.
- **Show Selected clicks**: How often users filter to view only selected contacts in the picker.

### Suggestions
- **Generated per session**: Is the algorithm surfacing anything at all? Zero means no free slot + overdue friend overlap was found.
- **Tap rate vs. dismiss rate**: The core quality signal. High dismiss rate = suggestions are off-target (wrong person, wrong time). High tap rate = the algorithm is working.
- `SuggestionTapped` = "Yes, let's do it!" (user engaged). `SuggestionDismissed` = "Maybe Later" (user passed).

### Invitations
The invitation funnel — drop-off at each stage points to a different problem:

```
SuggestionViewed
        ↓
SuggestionTapped / InvitationInitiated   ("Yes, let's do it!")
        ↓  drop-off here = ScheduledView caused hesitation
InvitationCompleted                       ("Send Invite" tapped → iMessage opened)
```

- **Initiation rate**: Of users who see a suggestion, how many tap "Yes"? (= `InvitationInitiated` / `SuggestionViewed`)
- **Completion rate**: Of users who tapped "Yes", how many actually sent the iMessage? Drop-off means the ScheduledView screen created second thoughts.
- **Time to send** (`timeElapsed`): How long between "Yes" and tapping "Send Invite"? Long time = hesitation on the confirmation screen.
- **Activity type**: Which activities convert best — useful for pruning the activity pool.
- **Time of day**: Are certain time slots (morning/afternoon/evening) more likely to convert?
- **Free slot suggested**: Was the AI-suggested time used? (`isFreeSlotSuggested: true` on all current invitations since the app always provides a suggested slot.)

*Not yet wired (require future UI):*
- `InvitationAbandoned` — backing out of ScheduledView without sending; needs a cancel/back gesture
- `InvitationResponse` — tracking whether the recipient said yes/maybe/no; needs recipient-side feature
- `FreeSlotAccepted` — whether user changed the suggested time; needs time-editing UI in ScheduledView

### Connections
- **Avg friends added per user**: Core adoption metric — are users actually populating their list?
- **% of address book added** (`avgPercentageAdded`): What fraction of their contacts did they bring into Eta? Low % may mean the picker UI is too slow, or they only added a few manually.
  - Computed from the *final* `ConnectionAdded` event per session, so it reflects where the user stopped.
  - `isInitialAdd: true` = first batch from the picker; `isInitialAdd: false` = went back and added more later.
- **Removed**: Did any users delete a friend? Signals friction in the add flow (added the wrong person).
- **Edit rate** and **Show Selected**: *Not yet wired* — no contact editing flow or "Show Selected" button exists in the current app.

### Navigation & Screen Time
- **Time per screen**: Unusually long time on a screen often means confusion. Tracked on: `SuggestionView`, `ConnectionsView`, `AddConnectionSheet`.
- **Button tap sequences**: Full trace of taps in order — useful for spotting unexpected navigation paths.
- **Steps to invitation**: How many screen transitions happened before the first invite was sent?

## Privacy Note

Analytics data includes session IDs, event timestamps, contact names (if tracked), and screen names. **Do not commit real user data.** The `.gitignore` excludes `Data/*.csv`, `Data/*.json`, and `Data/*.png` — keep exported files out of git.

## Questions?

See `AnalyticsService.swift` for exactly what is logged per event.
