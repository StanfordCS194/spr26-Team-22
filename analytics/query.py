#!/usr/bin/env python3
"""
Eta Analytics - Interactive Query Tool

Usage:
    python3 query.py

Interactive tool for exploring analytics data.
"""

import pandas as pd
from pathlib import Path
import json

def load_data():
    """Load the most recent analytics data."""
    data_path = Path("Data")
    csv_files = list(data_path.glob("eta_analytics_*.csv"))
    
    if not csv_files:
        print("❌ No analytics data found in Data/ folder")
        return None
    
    csv_file = max(csv_files, key=lambda p: p.stat().st_mtime)
    print(f"📂 Loaded: {csv_file.name}\n")
    
    return pd.read_csv(csv_file)

def show_help():
    """Display available commands."""
    print("\n" + "=" * 60)
    print("  AVAILABLE COMMANDS")
    print("=" * 60)
    print("  sessions        - List all user sessions")
    print("  user <id>       - Show events for a specific session")
    print("  type <event>    - Filter events by type")
    print("  category <cat>  - Filter events by category")
    print("  time <screen>   - Show screen time for a specific screen")
    print("  permissions     - Show all permission events")
    print("  invitations     - Show all invitation events")
    print("  stats           - Show quick statistics")
    print("  export <query>  - Export query results to CSV")
    print("  help            - Show this help message")
    print("  exit            - Quit the tool")
    print("=" * 60 + "\n")

def cmd_sessions(df):
    """List all sessions."""
    sessions = df.groupby('SessionID').agg({
        'Timestamp': ['min', 'max', 'count']
    })
    sessions.columns = ['First Event', 'Last Event', 'Event Count']
    print("\n" + sessions.to_string())
    print(f"\nTotal sessions: {len(sessions)}\n")

def cmd_user(df, session_partial):
    """Show events for a specific user/session."""
    # Find sessions that contain the partial ID
    matching = df[df['SessionID'].str.contains(session_partial, case=False)]
    
    if matching.empty:
        print(f"❌ No session found matching '{session_partial}'")
        return
    
    sessions = matching['SessionID'].unique()
    if len(sessions) > 1:
        print(f"⚠️  Multiple sessions match '{session_partial}':")
        for s in sessions:
            print(f"   {s}")
        print("Please be more specific.\n")
        return
    
    print(f"\n📋 Session: {sessions[0]}")
    print("=" * 80)
    print(matching[['Timestamp', 'EventType', 'Category', 'Value']].to_string(index=False))
    print(f"\nTotal events: {len(matching)}\n")

def cmd_type(df, event_type):
    """Filter events by type."""
    matching = df[df['EventType'].str.contains(event_type, case=False)]
    
    if matching.empty:
        print(f"❌ No events found with type containing '{event_type}'")
        return
    
    print(f"\n📋 Events matching '{event_type}':")
    print("=" * 80)
    print(matching[['SessionID', 'Timestamp', 'EventType', 'Value']].to_string(index=False))
    print(f"\nTotal: {len(matching)} events\n")

def cmd_category(df, category):
    """Filter events by category."""
    matching = df[df['Category'].str.contains(category, case=False)]
    
    if matching.empty:
        print(f"❌ No events found in category '{category}'")
        return
    
    print(f"\n📋 Events in category '{category}':")
    print("=" * 80)
    print(matching[['SessionID', 'Timestamp', 'EventType', 'Value']].to_string(index=False))
    print(f"\nTotal: {len(matching)} events\n")

def cmd_time(df, screen):
    """Show screen time for a specific screen."""
    screen_exits = df[(df['EventType'] == 'ScreenExited') & (df['Value'].str.contains(screen, case=False))]
    
    if screen_exits.empty:
        print(f"❌ No screen time data for '{screen}'")
        return
    
    print(f"\n⏱️  Screen time for '{screen}':")
    print("=" * 80)
    
    for _, row in screen_exits.iterrows():
        try:
            metadata = json.loads(row['Metadata'].replace(';', ','))
            duration = metadata.get('duration', 0)
            print(f"{row['SessionID']}: {duration:.1f}s")
        except:
            print(f"{row['SessionID']}: [unable to parse]")
    
    print()

def cmd_permissions(df):
    """Show all permission-related events."""
    perms = df[df['Category'] == 'Permission']
    
    print("\n📱 Permission Events:")
    print("=" * 80)
    print(perms[['SessionID', 'EventType', 'Value', 'Metadata']].to_string(index=False))
    print(f"\nTotal: {len(perms)} events\n")

def cmd_invitations(df):
    """Show all invitation-related events."""
    invs = df[df['Category'] == 'Invitation']
    
    print("\n📨 Invitation Events:")
    print("=" * 80)
    print(invs[['SessionID', 'Timestamp', 'EventType', 'Value']].to_string(index=False))
    print(f"\nTotal: {len(invs)} events\n")

def cmd_stats(df):
    """Show quick statistics."""
    print("\n📊 Quick Statistics:")
    print("=" * 60)
    print(f"Total sessions: {df['SessionID'].nunique()}")
    print(f"Total events: {len(df)}")
    print(f"Event types: {df['EventType'].nunique()}")
    print(f"Categories: {df['Category'].nunique()}")
    
    print(f"\nEvents by category:")
    print(df['Category'].value_counts().to_string())
    
    print(f"\nTop event types:")
    print(df['EventType'].value_counts().head(10).to_string())
    print()

def main():
    """Main interactive query loop."""
    print("\n🔍 Eta Analytics Query Tool")
    print("=" * 60)
    
    df = load_data()
    if df is None:
        return
    
    show_help()
    
    while True:
        try:
            cmd_input = input("eta> ").strip()
            
            if not cmd_input:
                continue
            
            parts = cmd_input.split(maxsplit=1)
            cmd = parts[0].lower()
            arg = parts[1] if len(parts) > 1 else None
            
            if cmd == 'exit' or cmd == 'quit':
                print("\n👋 Goodbye!\n")
                break
            
            elif cmd == 'help':
                show_help()
            
            elif cmd == 'sessions':
                cmd_sessions(df)
            
            elif cmd == 'user':
                if not arg:
                    print("❌ Usage: user <session_id>")
                else:
                    cmd_user(df, arg)
            
            elif cmd == 'type':
                if not arg:
                    print("❌ Usage: type <event_type>")
                else:
                    cmd_type(df, arg)
            
            elif cmd == 'category':
                if not arg:
                    print("❌ Usage: category <category>")
                else:
                    cmd_category(df, arg)
            
            elif cmd == 'time':
                if not arg:
                    print("❌ Usage: time <screen_name>")
                else:
                    cmd_time(df, arg)
            
            elif cmd == 'permissions':
                cmd_permissions(df)
            
            elif cmd == 'invitations':
                cmd_invitations(df)
            
            elif cmd == 'stats':
                cmd_stats(df)
            
            else:
                print(f"❌ Unknown command: {cmd}")
                print("   Type 'help' for available commands")
        
        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!\n")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()
