#!/usr/bin/env python3
"""
Eta Analytics - Data Analysis Script

Usage:
    python3 analyze.py

This script loads analytics data exported from the Eta app and displays
key statistics and insights.
"""

import json
import pandas as pd
from pathlib import Path
from datetime import datetime

def load_latest_analytics(data_dir="Data"):
    """Load the most recent analytics export files."""
    data_path = Path(data_dir)
    
    # Find most recent files
    csv_files = list(data_path.glob("eta_analytics_*.csv"))
    json_files = list(data_path.glob("eta_analytics_*.json"))
    summary_files = list(data_path.glob("eta_summary_*.json"))
    
    if not csv_files:
        print("❌ No analytics data found in Data/ folder")
        print("   Export data from the app (triple-tap bottom-right corner)")
        return None, None, None
    
    csv_file = max(csv_files, key=lambda p: p.stat().st_mtime)
    json_file = max(json_files, key=lambda p: p.stat().st_mtime) if json_files else None
    summary_file = max(summary_files, key=lambda p: p.stat().st_mtime) if summary_files else None
    
    print(f"📂 Loading: {csv_file.name}")
    
    # Load CSV
    df = pd.read_csv(csv_file)
    
    # Load JSON files if available
    structured = None
    if json_file:
        with open(json_file) as f:
            structured = json.load(f)
    
    summary = None
    if summary_file:
        with open(summary_file) as f:
            summary = json.load(f)
    
    return df, structured, summary

def print_header(title):
    """Print a formatted section header."""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}\n")

def analyze_permissions(df, summary):
    """Analyze permission grant rates and timing."""
    print_header("📱 PERMISSIONS")
    
    if summary and 'permissions' in summary:
        perms = summary['permissions']
        
        # Calendar
        cal = perms['calendar']
        print(f"Calendar Access:")
        print(f"  Requested: {cal['requested']}")
        print(f"  Granted: {cal['granted']} ({cal['grantRate']:.1f}%)")
        print(f"  Denied: {cal['denied']}")
        print(f"  Avg time to grant: {cal['avgTimeToGrant']:.1f}s")
        
        # Contacts
        con = perms['contacts']
        print(f"\nContacts Access:")
        print(f"  Requested: {con['requested']}")
        print(f"  Granted: {con['granted']} ({con['grantRate']:.1f}%)")
        print(f"  Denied: {con['denied']}")
        print(f"  Avg time to grant: {con['avgTimeToGrant']:.1f}s")
        
        if con.get('selectionType'):
            print(f"  Selection type: {con['selectionType']}")
    else:
        # Fallback to raw data
        perm_events = df[df['Category'] == 'Permission']
        print(perm_events[['SessionID', 'EventType', 'Value']].to_string(index=False))

def analyze_onboarding(summary):
    """Analyze onboarding completion and duration."""
    print_header("🚀 ONBOARDING")
    
    if summary and 'onboarding' in summary:
        ob = summary['onboarding']
        print(f"Completion rate: {ob['completionRate']:.1f}%")
        print(f"Average duration: {ob['avgDuration']:.1f}s ({ob['avgDuration']/60:.1f} min)")
    else:
        print("No onboarding data available")

def analyze_connections(summary):
    """Analyze connection management behavior."""
    print_header("👥 CONNECTIONS")

    if summary and 'connections' in summary:
        conn = summary['connections']
        print(f"Total connections added: {conn['totalAdded']}")
        print(f"Total connections removed: {conn.get('totalRemoved', 0)}")
        print(f"Average per user: {conn['avgPerUser']:.1f}")
        print(f"Average contacts available: {conn['avgContactsAvailable']:.0f}")
        print(f"Average % of contacts added: {conn['avgPercentageAdded']:.1f}%")
        print(f"Connections edited: {conn['edited']} ({conn['editRate']:.1f}%)")
        print(f"'Show Selected' clicks: {conn['showSelectedClicks']}")
    else:
        print("No connection data available")

def analyze_suggestions(summary):
    """Analyze suggestion engagement."""
    print_header("✨ SUGGESTIONS")

    if summary and 'suggestions' in summary:
        sug = summary['suggestions']
        print(f"Total generated: {sug['totalGenerated']}")
        print(f"Average per session: {sug['avgPerSession']:.1f}")
        print(f"Viewed: {sug['viewed']}")
        tapped = sug['tapped']
        dismissed = sug.get('dismissed', 0)
        print(f"Accepted (tapped): {tapped} ({sug['tapRate']:.1f}% of interactions)")
        print(f"Maybe Later (dismissed): {dismissed} ({sug.get('dismissRate', 0):.1f}% of interactions)")
    else:
        print("No suggestion data available")

def analyze_invitations(summary):
    """Analyze invitation flow and outcomes."""
    print_header("📨 INVITATIONS")
    
    if summary and 'invitations' in summary:
        inv = summary['invitations']
        print(f"Initiated: {inv['initiated']}")
        print(f"Completed: {inv['completed']} ({inv['completionRate']:.1f}%)")
        print(f"Abandoned: {inv['abandoned']}")
        print(f"Average time to send: {inv['avgTimeToSend']:.1f}s")
        
        print(f"\nResponses:")
        for response, count in inv['responseBreakdown'].items():
            print(f"  {response}: {count}")
        
        print(f"\nBy time of day:")
        for time, count in inv['byTimeOfDay'].items():
            if count > 0:
                print(f"  {time}: {count}")
        
        print(f"\nBy activity:")
        for activity, count in inv['byActivity'].items():
            print(f"  {activity}: {count}")
        
        print(f"\nFree slot suggestions:")
        print(f"  Suggested: {inv['freeSlotSuggested']}")
        print(f"  Accepted: {inv['freeSlotAccepted']}")
    else:
        print("No invitation data available")

def analyze_screen_time(summary):
    """Analyze time spent on different screens."""
    print_header("⏱️  SCREEN TIME")
    
    if summary and 'screenTime' in summary:
        st = summary['screenTime']
        
        # Sort by total time
        sorted_screens = sorted(st.items(), key=lambda x: x[1]['totalTime'], reverse=True)
        
        print(f"{'Screen':<30} {'Total (s)':<12} {'Avg (s)':<12} {'Views':<8}")
        print("-" * 62)
        for screen, stats in sorted_screens:
            print(f"{screen:<30} {stats['totalTime']:<12.1f} {stats['avgTime']:<12.1f} {stats['views']:<8}")
    else:
        print("No screen time data available")

def analyze_sessions(df, structured):
    """Analyze per-session details, grouping by username from notes where available."""
    print_header("👤 USER SESSIONS")

    sessions = df.groupby('SessionID').agg(
        first_event=('Timestamp', 'min'),
        last_event=('Timestamp', 'max'),
        event_count=('Timestamp', 'count')
    ).reset_index()

    # Attach notes from structured JSON if available
    notes_map = {}
    if structured:
        for s in structured.get('sessions', []):
            notes_map[s['sessionID']] = s.get('notes', '').strip()

    sessions['notes'] = sessions['SessionID'].map(notes_map).fillna('')

    # Group sessions with the same non-empty username as the same user
    # Username = first word of notes (everything before first space or dash)
    def extract_username(notes):
        if not notes:
            return None
        return notes.split()[0].rstrip('-').strip() if notes.split() else None

    sessions['username'] = sessions['notes'].apply(extract_username)

    print(f"Total sessions: {len(sessions)}")

    # Show user grouping if any notes have usernames
    named = sessions[sessions['username'].notna()]
    if not named.empty:
        user_groups = named.groupby('username')['SessionID'].apply(list)
        multi = user_groups[user_groups.apply(len) > 1]
        if not multi.empty:
            print(f"\nMulti-session users (same username across sessions):")
            for user, sids in multi.items():
                print(f"  {user}: {len(sids)} sessions — {', '.join(sids)}")

    print(f"\nSession details:")
    for _, row in sessions.iterrows():
        label = f"  [{row['username']}]" if row['username'] else ""
        print(f"  {row['SessionID']}{label}  events={row['event_count']}")

def main():
    """Main analysis function."""
    print("\n🎯 Eta Analytics Analysis")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    df, structured, summary = load_latest_analytics()
    
    if df is None:
        return
    
    # Run all analyses
    analyze_permissions(df, summary)
    analyze_onboarding(summary)
    analyze_connections(summary)
    analyze_suggestions(summary)
    analyze_invitations(summary)
    analyze_screen_time(summary)
    analyze_sessions(df, structured)
    
    print(f"\n{'=' * 60}")
    print("✅ Analysis complete!")
    print(f"{'=' * 60}\n")

if __name__ == "__main__":
    main()
