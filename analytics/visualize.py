#!/usr/bin/env python3
"""
Eta Analytics - Visualization Script

Usage:
    python3 visualize.py

This script generates charts and visualizations from analytics data.
"""

import json
import pandas as pd
from pathlib import Path
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

def load_summary():
    """Load the most recent summary stats file."""
    data_path = Path("Data")
    summary_files = list(data_path.glob("eta_summary_*.json"))
    
    if not summary_files:
        print("❌ No summary data found in Data/ folder")
        return None
    
    summary_file = max(summary_files, key=lambda p: p.stat().st_mtime)
    print(f"📂 Loading: {summary_file.name}")
    
    with open(summary_file) as f:
        return json.load(f)

def plot_permission_funnel(summary):
    """Create permission funnel visualization."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
    
    # Calendar permissions
    cal = summary['permissions']['calendar']
    ax1.bar(['Requested', 'Granted', 'Denied'], 
            [cal['requested'], cal['granted'], cal['denied']],
            color=['#007AFF', '#34C759', '#FF3B30'])
    ax1.set_title('Calendar Permissions', fontsize=14, fontweight='bold')
    ax1.set_ylabel('Count')
    ax1.grid(axis='y', alpha=0.3)
    
    # Contacts permissions
    con = summary['permissions']['contacts']
    ax2.bar(['Requested', 'Granted', 'Denied'], 
            [con['requested'], con['granted'], con['denied']],
            color=['#007AFF', '#34C759', '#FF3B30'])
    ax2.set_title('Contact Permissions', fontsize=14, fontweight='bold')
    ax2.set_ylabel('Count')
    ax2.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('Data/permission_funnel.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: Data/permission_funnel.png")
    plt.close()

def plot_invitation_funnel(summary):
    """Create invitation conversion funnel."""
    inv = summary['invitations']
    
    stages = ['Initiated', 'Completed', 'Yes Response']
    counts = [inv['initiated'], inv['completed'], inv['responseBreakdown'].get('yes', 0)]
    colors = ['#007AFF', '#5AC8FA', '#34C759']
    
    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(stages, counts, color=colors)
    
    # Add percentage labels on bars
    for i, (bar, count) in enumerate(zip(bars, counts)):
        if i > 0 and counts[0] > 0:
            pct = (count / counts[0]) * 100
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
                   f'{pct:.0f}%', ha='center', va='bottom', fontweight='bold')
    
    ax.set_title('Invitation Conversion Funnel', fontsize=16, fontweight='bold')
    ax.set_ylabel('Count')
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('Data/invitation_funnel.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: Data/invitation_funnel.png")
    plt.close()

def plot_screen_time(summary):
    """Create screen time visualization."""
    st = summary['screenTime']
    
    if not st:
        print("⚠️  No screen time data to visualize")
        return
    
    # Sort by total time
    sorted_screens = sorted(st.items(), key=lambda x: x[1]['totalTime'], reverse=True)
    screens = [s[0] for s in sorted_screens]
    times = [s[1]['totalTime'] for s in sorted_screens]
    
    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.barh(screens, times, color='#5856D6')
    
    ax.set_title('Time Spent on Each Screen', fontsize=16, fontweight='bold')
    ax.set_xlabel('Total Time (seconds)')
    ax.grid(axis='x', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('Data/screen_time.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: Data/screen_time.png")
    plt.close()

def plot_activity_breakdown(summary):
    """Create activity type breakdown."""
    inv = summary['invitations']
    activities = inv['byActivity']
    
    if not activities:
        print("⚠️  No activity data to visualize")
        return
    
    labels = list(activities.keys())
    sizes = list(activities.values())
    colors = plt.cm.Set3(range(len(labels)))
    
    fig, ax = plt.subplots(figsize=(8, 8))
    ax.pie(sizes, labels=labels, autopct='%1.1f%%', startangle=90, colors=colors)
    ax.set_title('Invitation Activities Distribution', fontsize=16, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('Data/activity_breakdown.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: Data/activity_breakdown.png")
    plt.close()

def plot_time_of_day(summary):
    """Create time of day preference chart."""
    inv = summary['invitations']
    tod = inv['byTimeOfDay']
    
    times = ['morning', 'afternoon', 'evening']
    counts = [tod.get(t, 0) for t in times]
    colors = ['#FFCC00', '#FF9500', '#5856D6']
    
    fig, ax = plt.subplots(figsize=(8, 6))
    bars = ax.bar(times, counts, color=colors)
    
    ax.set_title('Invitation Time of Day Preference', fontsize=16, fontweight='bold')
    ax.set_ylabel('Count')
    ax.set_xlabel('Time of Day')
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('Data/time_of_day.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: Data/time_of_day.png")
    plt.close()

def plot_response_breakdown(summary):
    """Create response type breakdown."""
    inv = summary['invitations']
    responses = inv['responseBreakdown']
    
    labels = list(responses.keys())
    sizes = list(responses.values())
    colors = ['#34C759', '#FF9500', '#FF3B30'][:len(labels)]
    
    fig, ax = plt.subplots(figsize=(8, 8))
    ax.pie(sizes, labels=labels, autopct='%1.1f%%', startangle=90, colors=colors)
    ax.set_title('Invitation Response Distribution', fontsize=16, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('Data/response_breakdown.png', dpi=300, bbox_inches='tight')
    print("✅ Saved: Data/response_breakdown.png")
    plt.close()

def main():
    """Main visualization function."""
    print("\n📊 Eta Analytics Visualization")
    print("=" * 60)
    
    summary = load_summary()
    
    if not summary:
        return
    
    print("\nGenerating visualizations...\n")
    
    plot_permission_funnel(summary)
    plot_invitation_funnel(summary)
    plot_screen_time(summary)
    plot_activity_breakdown(summary)
    plot_time_of_day(summary)
    plot_response_breakdown(summary)
    
    print("\n" + "=" * 60)
    print("✅ All visualizations complete!")
    print("   Check the Data/ folder for PNG files")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    main()
