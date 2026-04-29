# MVP Testing Guide

**Delete the app between users.** This gives each user a clean install: fresh permission prompts, empty friends list, new session ID.

---

## Quick Facts

- Each app install = one user session
- Data persists until you delete the app — **export before deleting!**
- Triple-tap bottom-right → Export with session notes
- Drop all export files from all teammates into `analytics/Data/` to combine results

---

## Testing Workflow

```
1. Install app on phone
2. Hand phone to user — they open the app fresh
3. User tests the app
4. Triple-tap bottom-right → Add session notes → Export → AirDrop to Mac
5. DELETE APP from phone
6. Reinstall
7. Repeat for next user
```

Each deletion clears all data — **must export first!**

---

## How to Export

1. **Triple-tap bottom-right corner**
2. **See list of all sessions** (timestamps, event counts)
3. **Expand each session** → Add notes (user name, observations)
4. **(Optional)** Deselect sessions you don't want
5. **Tap "Export"**
6. **AirDrop/Save** 3 files to your Mac

---

## What Gets Exported

**3 files per export:**

1. `eta_analytics_*.csv` - Raw event data
2. `eta_analytics_*.json` - Structured session data
3. `eta_summary_*.json` - Pre-computed stats

---

## Analyze Data

```bash
cd analytics

python3 analyze.py      # View statistics
python3 visualize.py    # Generate charts
python3 query.py        # Interactive exploration
```

If multiple teammates each ran testing sessions, drop all exported files from all devices into `analytics/Data/` and run the scripts together.

---

## Key Points

- **Export before deleting** — app deletion clears all data
- **Add session notes during export** — helps match data to specific users
- **All sessions selected by default** — deselect if needed
- **Each install = fresh permission prompts** — this is what makes permissions KPIs meaningful

---

## KPIs Tracked

- Permissions (calendar, contacts — grant rate, time to grant)
- Onboarding (time from launch to first friend added, completion rate)
- Connections (friends added, % of address book, edits)
- Suggestions (generated, viewed, tapped)
- Invitations (initiated, completed, responses)
- Screen time (all screens)
- Navigation (button taps, flows)

---

## Troubleshooting

**Triple-tap not working?**
- Must be DEBUG build
- Tap bottom-right corner (80x80 area)

**Python errors?**
```bash
pip3 install pandas matplotlib
```
