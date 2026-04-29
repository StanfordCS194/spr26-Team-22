# Quick Reference for Testing

## Before Testing Starts

1. Build app in DEBUG mode
2. Install on test device
3. Know the **triple-tap bottom-right corner** gesture for exporting

## For Each User

1. **Install app** — fresh install gives clean state (empty friends, new session ID, permission prompts ready)
2. **Hand phone to user** — everything is tracked automatically
3. **User tests the app** — take qualitative notes on the side if useful
4. **After session:** triple-tap → add session notes → Export → AirDrop to Mac
5. **Delete app** from phone
6. **Reinstall** for next user

## After All Testing

Drop all exported files into `analytics/Data/` and run:

```bash
cd analytics

python3 analyze.py      # Summary statistics
python3 visualize.py    # Generate charts
python3 query.py        # Explore data
```

## Stats for Wiki

Run `analyze.py` and copy these sections:
- Permissions (grant rates, time to grant)
- Onboarding (completion, duration)
- Connections (count, percentage added)
- Suggestions (engagement, tap rate)
- Invitations (conversion funnel)
- Screen time (by screen)

## Visualizations for Wiki

From `visualize.py` output (saved in `Data/`):
- `permission_funnel.png`
- `invitation_funnel.png`
- `screen_time.png`
- `activity_breakdown.png`
- `time_of_day.png`
- `response_breakdown.png`

## Troubleshooting

**Triple-tap not working?**
- Bottom-right corner (80x80 point area)
- Must be DEBUG build

**Python errors?**
```bash
pip3 install pandas matplotlib
```

## What's Being Tracked

- **Permissions:** Calendar, Contacts (grant rate, time)
- **Onboarding:** Time from launch to first friend added, completion rate
- **Connections:** Added, edited, % of address book
- **Suggestions:** Generated, viewed, tapped
- **Invitations:** Initiated, completed, responses
- **Navigation:** Screen time, button taps, flows
- **Sessions:** Unique ID per install, timestamps, event counts
