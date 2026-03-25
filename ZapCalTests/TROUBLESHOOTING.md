# Troubleshooting Guide

## Quick Diagnostics

Run through this checklist first:

```
□ App appears in menu bar
□ Menu bar icon is a bell (not bell.slash)
□ Clicking icon shows dropdown menu
□ Calendar access granted in System Settings
□ At least one calendar is selected in Settings
□ At least one upcoming event exists
□ Event is NOT all-day
□ Event is NOT declined
□ Alerts are NOT paused
```

If any checkbox is unchecked, jump to that section below.

---

## Common Issues & Solutions

### 1. "App doesn't appear in menu bar"

**Symptoms:**
- App launches but no icon appears
- Can't find the app anywhere

**Causes & Solutions:**

**A. Dock icon showing instead of menu bar**
- Check Info.plist has `LSUIElement` = `true`
- Clean build: ⌘ + Shift + K
- Delete derived data: ~/Library/Developer/Xcode/DerivedData/
- Rebuild and run

**B. App crashed on launch**
1. Check Console.app for crash logs
2. Filter by "Full Screen Calendar"
3. Look for error messages
4. Common crash causes:
   - SwiftData container creation failed
   - Model context not available
   - Missing entitlements

**C. Wrong build target**
- Ensure you're building the main app target, not tests
- Check scheme in Xcode toolbar

**D. Menu bar is full**
- macOS hides icons when menu bar is full
- Try expanding menu bar by dragging the left edge
- Or quit other menu bar apps

**Quick Test:**
```swift
// Add to AppDelegate.applicationDidFinishLaunching
print("Status item created: \(statusItem != nil)")
print("Status bar button: \(statusItem?.button != nil)")
```

---

### 2. "Calendar permission not requested"

**Symptoms:**
- App launches but never asks for calendar access
- Menu shows "Calendar Access Required"

**Causes & Solutions:**

**A. Missing Info.plist key**
1. Open Info.plist
2. Check for `NSCalendarsUsageDescription`
3. If missing, add:
```xml
<key>NSCalendarsUsageDescription</key>
<string>ZapCal needs access to your calendars to display full-screen alerts for your events.</string>
```
4. Clean build and run

**B. Missing entitlement**
1. Check .entitlements file
2. Ensure it has:
```xml
<key>com.apple.security.personal-information.calendars</key>
<true/>
```

**C. Already denied in past**
1. Reset permissions:
```bash
tccutil reset Calendar
```
2. Restart app
3. Permission prompt should appear

**D. System Settings → Privacy & Security**
Manually enable:
1. System Settings
2. Privacy & Security
3. Calendars
4. Enable for ZapCal

---

### 3. "No calendars appear in Settings"

**Symptoms:**
- Calendar access granted
- Settings → Calendars is empty

**Causes & Solutions:**

**A. No calendars configured in macOS**
1. Open macOS Calendar app
2. If you see "No Calendars", add one
3. System Settings → Internet Accounts
4. Add iCloud, Google, or other account

**B. Calendar.app not synced yet**
- Wait a few seconds for EventKit to sync
- Quit and restart ZapCal
- Check Calendar.app shows events

**C. EventKit authorization status wrong**
```swift
// Debug in CalendarService
print("Auth status: \(EKEventStore.authorizationStatus(for: .event))")
print("Available calendars: \(eventStore.calendars(for: .event).count)")
```

---

### 4. "Alerts don't appear for my events"

**Symptoms:**
- Events show in menu bar
- But no full-screen alert at start time

**Diagnostic Checklist:**

**A. Are alerts paused?**
- Check menu bar icon
- If it's `bell.slash.fill`, alerts are paused
- Click → "Unpause ZapCal"

**B. Is the event all-day?**
- All-day events don't trigger alerts (by design)
- Check event in Calendar.app
- Change to specific time if needed

**C. Is the event declined?**
- Check participation status in Calendar.app
- Declined events don't trigger alerts
- Change status to "Accepted" or "Maybe"

**D. Is the calendar selected?**
1. Settings → Calendars
2. Find the event's calendar
3. Ensure toggle is ON

**E. Did you miss the start time?**
- App doesn't fire retroactive alerts (by design)
- Exception: Within 2 minutes after wake from sleep

**F. Is the event in the past?**
- Only future events trigger alerts
- Check event date/time

**Debug Mode:**
```swift
// Add to CalendarService.checkForEventsToFire()
print("Checking events...")
print("Now: \(Date())")
print("Upcoming events: \(upcomingEvents.count)")
print("Paused: \(AppSettings.shared.isPaused)")
print("Fired IDs: \(firedEventIDs)")

for event in upcomingEvents {
    print("- \(event.title): \(event.startDate)")
    print("  Should fire: \(event.startDate <= Date())")
    print("  Already fired: \(firedEventIDs.contains(event.id))")
    print("  Should trigger: \(event.shouldTriggerAlert)")
}
```

---

### 5. "Alert appears but I can't dismiss it"

**Symptoms:**
- Alert shows on screen
- Clicking X does nothing
- Escape key doesn't work

**Solutions:**

**A. Keyboard focus issue**
- Click somewhere on the alert first
- Then press Escape
- Or click the X button repeatedly

**B. Multiple displays**
- The X button only appears on primary display
- Check all screens for the dismiss button

**C. Window level issue**
```swift
// Verify in AlertCoordinator.createAlertWindow
print("Window level: \(window.level.rawValue)")
print("Window key: \(window.isKeyWindow)")
```

**Emergency Exit:**
```bash
# Force quit if stuck
killall "ZapCal"
```

---

### 6. "Alert doesn't overlay full-screen apps"

**Symptoms:**
- Alert works normally
- But doesn't show over full-screen apps (presentations, games)

**Known Issue:**
This is a macOS sandboxing limitation for some full-screen apps.

**Workarounds:**
1. Exit full-screen mode temporarily
2. Use a second display (alert will show there)
3. File a Radar with Apple for sandbox improvements

**Technical:**
The app uses:
- `window.level = .screenSaver`
- `window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`

This works for MOST full-screen apps but not all.

---

### 7. "Customizations don't save"

**Symptoms:**
- Change theme in Settings
- Click Save
- Restart app
- Changes are gone

**Causes & Solutions:**

**A. Not clicking Save**
- Theme editor has "Revert" and "Save" buttons
- Must click Save to persist changes

**B. UserDefaults issue**
```bash
# Check if UserDefaults are being written
defaults read com.yourcompany.Full-Screen-Calendar-Reminder
```

**C. Sandbox permissions**
- Verify app is properly signed
- Check entitlements are active

**D. Manual fix**
```swift
// Force save in ThemeService
ThemeService.shared.saveThemes()
```

---

### 8. "Launch at Login doesn't work"

**Symptoms:**
- Enabled "Launch at Login" in Settings
- But app doesn't start on reboot

**Requirements:**
- macOS 13.0+
- App properly signed
- Sandboxing enabled

**Solutions:**

**A. Check login items**
```bash
launchctl list | grep -i "calendar"
```

**B. Re-register**
```swift
// Run this in a playground or add temporary button
Task {
    try? await SMAppService.mainApp.unregister()
    try? await SMAppService.mainApp.register()
}
```

**C. System Settings**
1. System Settings → General → Login Items
2. Look for "ZapCal"
3. Ensure it's enabled

**D. Known Issue: Debug builds**
- Launch at login may not work with debug builds
- Create a Release build for testing

---

### 9. "Menu bar dropdown is blank"

**Symptoms:**
- Click bell icon
- Dropdown appears but shows nothing

**Causes & Solutions:**

**A. No upcoming events**
- Check Calendar.app has events in the future
- Create a test event

**B. No calendars selected**
- Settings → Calendars
- Select at least one calendar

**C. Calendar permission denied**
- Will show "Calendar Access Required" message
- Grant permission

**D. View not updating**
```swift
// Force refresh
Task {
    await CalendarService.shared.fetchUpcomingEvents()
}
```

---

### 10. "Video conference Join button doesn't work"

**Symptoms:**
- Event has a Zoom/Meet link
- Join button doesn't appear
- Or clicking it does nothing

**Causes & Solutions:**

**A. URL not detected**
Supported patterns:
- zoom.us
- meet.google.com
- teams.microsoft.com
- webex.com
- facetime://

If your link doesn't match, it won't be detected.

**B. Add custom pattern**
Edit `CalendarEvent.extractVideoConferenceURL`:
```swift
let patterns = [
    // existing patterns
    "your.custom.url"
]
```

**C. Check event notes/location**
- URL must be in notes, location, or structured data
- Try moving URL to different field

**D. Debug**
```swift
print("Event: \(event.title)")
print("Notes: \(event.notes ?? "nil")")
print("Location: \(event.location ?? "nil")")
print("Video URL: \(event.videoConferenceURL?.absoluteString ?? "nil")")
```

---

## Advanced Debugging

### Enable Verbose Logging

Add to AppDelegate:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    UserDefaults.standard.set(true, forKey: "DebugMode")
    // Rest of code...
}
```

Then throughout the code:
```swift
if UserDefaults.standard.bool(forKey: "DebugMode") {
    print("DEBUG: Something happened")
}
```

### Check SwiftData Store

```swift
// Print all reminders
let descriptor = FetchDescriptor<CustomReminder>()
let reminders = try? modelContext.fetch(descriptor)
print("Total reminders: \(reminders?.count ?? 0)")
```

### Check EventKit Status

```swift
// Calendar access
print("Status: \(EKEventStore.authorizationStatus(for: .event))")

// Available calendars
let calendars = eventStore.calendars(for: .event)
print("Calendars: \(calendars.count)")
for cal in calendars {
    print("- \(cal.title) (\(cal.source.title))")
}

// Upcoming events
let start = Date()
let end = start.addingTimeInterval(86400) // 24 hours
let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
let events = eventStore.events(matching: predicate)
print("Events next 24h: \(events.count)")
```

### Monitor Notifications

```swift
// Add observer for all notifications
NotificationCenter.default.addObserver(
    forName: nil,
    object: nil,
    queue: .main
) { notification in
    print("Notification: \(notification.name.rawValue)")
}
```

### Instruments Profiling

1. Product → Profile (⌘ + I)
2. Choose template:
   - **Leaks** - Memory leaks
   - **Time Profiler** - Performance
   - **Allocations** - Memory usage
3. Run all features
4. Look for issues

---

## Reset Everything

If all else fails, nuclear option:

```bash
# Kill app
killall "ZapCal"

# Clear UserDefaults
defaults delete com.yourcompany.Full-Screen-Calendar-Reminder

# Clear SwiftData (app container)
# Location varies, use Finder to go to:
# ~/Library/Containers/com.yourcompany.Full-Screen-Calendar-Reminder/
# Delete the entire folder

# Reset calendar permissions
tccutil reset Calendar

# Clean Xcode build
# Xcode: Product → Clean Build Folder (⌘ + Shift + K)

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Full_Screen_Calendar_Reminder-*

# Rebuild from scratch
```

---

## Getting More Help

### Check Console.app

1. Open Console.app
2. Filter: "Full Screen Calendar"
3. Look for errors or crashes
4. Note the timestamp and error message

### Xcode Debug Console

When running from Xcode:
- Check debug console for print statements
- Look for errors in red
- Enable "All Exceptions" breakpoint

### System Information

Collect this info when asking for help:
- macOS version
- Xcode version
- App version
- Calendar provider (iCloud, Google, etc.)
- Number of calendars
- Number of upcoming events
- Console.app error messages

---

## Known Issues & Workarounds

### Issue: Alert doesn't show immediately at event start time

**Why:** 5-minute polling interval means up to 5-minute delay

**Workaround:** Reduce polling interval in CalendarService (at cost of battery)

---

### Issue: Custom reminders fire 1 minute late

**Why:** 1-minute polling for reminders

**Workaround:** Accept the trade-off or reduce interval

---

### Issue: Theme preview is small

**Why:** Scaled to 40% to fit in settings window

**Workaround:** Use "Preview Full Screen" button for actual size

---

### Issue: Font picker is text field not dropdown

**Why:** Simplified implementation

**Workaround:** Type font name exactly (e.g., "SF Pro", "Helvetica")

---

### Issue: Can't drag elements in theme editor

**Why:** Complex to implement with scaled preview

**Workaround:** Use X/Y position sliders

---

## Prevention Tips

### Regular Maintenance

1. **Keep calendars tidy**
   - Delete old events
   - Remove unused calendars

2. **Monitor storage**
   - Clear old custom reminders
   - Don't store huge images as backgrounds

3. **Update regularly**
   - Keep macOS updated
   - Rebuild app after major OS updates

### Best Practices

1. **Test alerts weekly**
   - Create a test event
   - Verify alert appears

2. **Backup themes**
   - Copy UserDefaults periodically
   ```bash
   defaults export com.yourcompany.Full-Screen-Calendar-Reminder ~/Desktop/backup.plist
   ```

3. **Review settings monthly**
   - Check selected calendars
   - Verify launch at login still works

---

## Still Not Working?

If you've tried everything above:

1. Check TODO.md for known limitations
2. Review ARCHITECTURE.md to understand the system
3. Create a GitHub issue with:
   - macOS version
   - Steps to reproduce
   - Console.app logs
   - Screenshots if applicable
4. Consider rebuilding from scratch following SETUP.md

---

**Remember:** Most issues are configuration-related. Double-check Info.plist, entitlements, and calendar permissions!
