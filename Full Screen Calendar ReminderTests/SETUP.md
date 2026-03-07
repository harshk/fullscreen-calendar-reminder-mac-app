# Setup Guide - Full Screen Calendar Reminder

## Quick Start (5 minutes)

### Step 1: Project Configuration

1. **Open the project in Xcode 15+**

2. **Configure your Info.plist**
   - Add the calendar usage description
   - Copy from `Info.plist.template` or add manually:
   ```xml
   <key>NSCalendarsUsageDescription</key>
   <string>Full Screen Calendar Reminder needs access to your calendars to display full-screen alerts for your events.</string>
   <key>LSUIElement</key>
   <true/>
   ```

3. **Configure Entitlements**
   - Make sure your `.entitlements` file includes:
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <true/>
   <key>com.apple.security.personal-information.calendars</key>
   <true/>
   <key>com.apple.security.files.user-selected.read-write</key>
   <true/>
   <key>com.apple.security.network.client</key>
   <true/>
   ```
   
4. **Select your Development Team**
   - In Xcode, go to Signing & Capabilities
   - Select your Apple Developer account

### Step 2: Build and Run

1. Press `⌘ + R` to build and run
2. The app will launch (no window will appear)
3. Look for the bell icon in your menu bar (top right)
4. Click the bell icon to see the menu

### Step 3: First Launch Setup

1. **Grant Calendar Access**
   - macOS will prompt for calendar permission
   - Click "OK" to allow access
   - If you miss the prompt, go to System Settings → Privacy & Security → Calendars

2. **Configure Calendars**
   - Click the bell icon → Settings
   - Go to the Calendars tab
   - By default, all calendars are selected
   - Deselect any calendars you don't want alerts for

3. **Test an Alert**
   - Go to Settings → Appearance
   - Click "Preview Full Screen" at the bottom
   - You should see a full-screen alert
   - Press Escape or click the X to dismiss

### Step 4: Create a Test Event

1. Open macOS Calendar app
2. Create an event starting in 2 minutes
3. Save the event
4. Wait for the alert to appear!

## Troubleshooting

### "The app won't build"

**Check these:**
- ✅ Xcode 15.0 or later
- ✅ macOS deployment target is 13.0
- ✅ Development team is selected
- ✅ All required files are in the project

**Common errors:**
- Missing entitlements → Copy from template
- Missing Info.plist keys → Copy from template
- Build errors → Make sure all files are added to target membership

### "Calendar permission isn't requested"

**Solutions:**
1. Check Info.plist has `NSCalendarsUsageDescription`
2. Check entitlements has calendar permission
3. Reset permissions: 
   ```bash
   tccutil reset Calendar
   ```
4. Rebuild and run

### "Alerts don't appear"

**Check these:**
1. Click bell icon → verify you see upcoming events
2. Check if alerts are paused (bell icon has a slash through it)
3. Verify event is:
   - Not all-day
   - Not declined
   - Starting at current time (within 2 minutes)
4. Check Console.app for errors

### "Menu bar icon doesn't appear"

**Solutions:**
1. Check `LSUIElement` is `true` in Info.plist
2. Quit the app completely and relaunch
3. Check AppDelegate is properly connected
4. Look in Activity Monitor for the process

### "Launch at Login doesn't work"

**Requirements:**
- App must be properly signed
- Sandboxing must be enabled
- SMAppService requires macOS 13+

**Debug:**
```bash
# Check login items
launchctl list | grep "Full Screen Calendar"
```

## Testing Checklist

Before you consider the app "working", test these:

- [ ] Menu bar icon appears
- [ ] Clicking icon shows dropdown menu
- [ ] Dropdown shows upcoming events (if you have any)
- [ ] Can open Settings
- [ ] Can select/deselect calendars
- [ ] Can create custom reminder
- [ ] Preview full-screen alert works (Settings → Appearance)
- [ ] Real event triggers alert at start time
- [ ] Can dismiss alert with Escape key
- [ ] Can dismiss alert with X button
- [ ] Pause toggle works (icon changes to bell.slash)
- [ ] When paused, alerts don't appear

## Development Tips

### Quick Testing Without Waiting

To test alerts without creating real calendar events:

1. Open `CalendarService.swift`
2. Add this to `startPolling()`:
   ```swift
   // Test alert in 5 seconds
   DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
       let testEvent = CalendarEvent.mock(title: "Test Alert")
       AlertCoordinator.shared.queueAlert(for: testEvent)
   }
   ```

### Viewing Logs

Open Console.app and filter for "Full Screen Calendar Reminder" to see debug output.

### Resetting All Data

To clear all settings and themes:
```bash
defaults delete com.yourcompany.Full-Screen-Calendar-Reminder
```

### Hot Reload for Theme Changes

The theme editor has live preview, but for full-screen preview:
1. Make changes in Settings → Appearance
2. Click "Preview Full Screen"
3. No need to wait for real events!

## Project Structure at a Glance

```
Models/          # Data structures
Services/        # Business logic
Views/           # UI components
  AlertView/     # Full-screen alert
  MenuBarView/   # Dropdown menu
  ReminderViews/ # Add/manage reminders
  SettingsView/  # Settings tabs
AppDelegate.swift     # Menu bar setup
*App.swift           # Entry point
```

## Next Steps

1. **Customize the appearance**
   - Settings → Appearance
   - Select a calendar
   - Change colors, fonts, positions
   - Preview full screen to see changes

2. **Add custom reminders**
   - Click bell icon → Add Full Screen Reminder
   - Set title and time
   - Test by setting time 1 minute in future

3. **Configure launch at login**
   - Settings → General
   - Toggle "Launch at Login"

4. **Test multi-display**
   - Connect second monitor
   - Trigger an alert
   - Should appear on both screens

## Deployment

### For Personal Use
The app works immediately after building. Just keep it running!

### For Distribution
1. Archive the app (Product → Archive)
2. Export with Developer ID signing
3. Notarize with Apple
4. Distribute .dmg or .pkg

### For Mac App Store
1. Use Mac App Store provisioning profile
2. Enable all required entitlements
3. Submit via App Store Connect

## Getting Help

If you encounter issues:

1. Check the README.md for troubleshooting
2. Read ARCHITECTURE.md to understand the system
3. Run the unit tests (⌘ + U)
4. Check Console.app for error messages
5. Review the PRD for expected behavior

## Feature Roadmap

See the PRD "Future Considerations" section for planned features:
- Advance alerts (X minutes before)
- Snooze functionality
- Sound alerts
- Named themes
- Theme import/export
- Keyboard shortcuts

The architecture is designed to easily accommodate these features!

---

**You're all set!** 🎉

The app should now be running in your menu bar. Create a test event and watch for the full-screen alert!
