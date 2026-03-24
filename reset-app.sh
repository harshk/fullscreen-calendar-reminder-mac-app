#!/bin/bash
# Simulate a fresh install of ZapCal by clearing all persisted data and permissions

# Kill the app if running
killall ZapCal 2>/dev/null

# Clear app support data (current and legacy names)
rm -rf ~/Library/Application\ Support/ZapCal/
rm -rf ~/Library/Application\ Support/Full\ Screen\ Calendar\ Reminder/

# Clear UserDefaults (current and legacy bundle IDs)
defaults delete spotlessmindsoftware.ZapCal 2>/dev/null
defaults delete harshapps.Full-Screen-Calendar-Reminder 2>/dev/null

# Reset calendar and reminders permissions
tccutil reset Calendar spotlessmindsoftware.ZapCal 2>/dev/null
tccutil reset Reminders spotlessmindsoftware.ZapCal 2>/dev/null

echo "ZapCal reset complete. Relaunch the app."
