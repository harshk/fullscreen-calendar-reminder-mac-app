#!/bin/bash
# Simulate a fresh install of ZapCal by clearing all persisted data and permissions

# Kill the app if running
killall ZapCal 2>/dev/null

# Sandboxed container paths
CONTAINER=~/Library/Containers/spotlessmindsoftware.ZapCal/Data/Library

# Clear app support data (themes, images, caches)
rm -rf "$CONTAINER/Application Support/ZapCal/"
rm -rf "$LEGACY_CONTAINER/Application Support/Full Screen Calendar Reminder/"

# Clear sandboxed UserDefaults
rm -f "$CONTAINER/Preferences/spotlessmindsoftware.ZapCal.plist"

# Also clear via defaults command in case of cached plist
defaults delete spotlessmindsoftware.ZapCal 2>/dev/null

# Reset calendar and reminders permissions
tccutil reset Calendar spotlessmindsoftware.ZapCal 2>/dev/null
tccutil reset Reminders spotlessmindsoftware.ZapCal 2>/dev/null

echo "ZapCal reset complete. Relaunch the app."
