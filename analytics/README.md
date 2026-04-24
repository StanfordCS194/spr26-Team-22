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
- Calendar access grant rate and time to grant
- Contacts access grant rate and time to grant
- Meaningful because each user starts from a fresh install — permission prompts fire every time

### Onboarding
- **Completion rate**: % of sessions where the user added at least one friend (`isInitialAdd: true` event)
- **Avg duration**: time from app launch to first friend added
- "Onboarding" in Eta = getting through the permission prompt and adding your first friend — there is no separate onboarding screen

### Connections
- Number of friends added per user (`avgPerUser`)
- **% of address book added** (`avgPercentageAdded`): computed from the final `ConnectionAdded` event per session — how much of their contacts list did they actually add to Eta?
  - Denominator = full address book size at time of adding (never shrinks)
  - `isInitialAdd: true` = first batch of adds (from address book picker); `isInitialAdd: false` = follow-up adds within the same session
- Edit rate (connections edited after adding)
- "Show Selected" button clicks

### Suggestions
- Number of suggestions generated per session
- Suggestion view rate
- Tap/interaction rate (yes vs maybe)

### Invitations *(ready for when feature ships)*
- Initiation rate, completion rate, abandonment rate
- Response breakdown (yes/maybe/no)
- Time to send
- Activity type preferences
- Time of day preferences (morning/afternoon/evening)
- Free slot suggested and accepted

### Navigation & Screen Time
- Time spent on each screen
- Navigation path to invitation
- Button tap sequences

## Privacy Note

Analytics data includes session IDs, event timestamps, contact names (if tracked), and screen names. **Do not commit real user data.** The `.gitignore` excludes `Data/*.csv`, `Data/*.json`, and `Data/*.png` — keep exported files out of git.

## Questions?

See `AnalyticsService.swift` for exactly what is logged per event.
