# Quick Start Checklist

Use this checklist to get the app running:

## ☑️ Configuration (Required Before Building)

### 1. Info.plist Configuration
- [ ] Open `Info.plist` in Xcode
- [ ] Add key: `NSCalendarsUsageDescription`
  - Value: `"ZapCal needs access to your calendars to display full-screen alerts for your events."`
- [ ] Add key: `LSUIElement`
  - Type: Boolean
  - Value: `YES` (this hides the Dock icon)
- [ ] Verify `LSMinimumSystemVersion` is `13.0`

### 2. Entitlements Configuration
- [ ] Select your app target in Xcode
- [ ] Go to "Signing & Capabilities" tab
- [ ] Click "+ Capability" → Add "App Sandbox"
- [ ] Under App Sandbox, enable:
  - [ ] Calendar (under "Personal Information")
  - [ ] User Selected Files → Read/Write (under "File Access")
  - [ ] Outgoing Connections (Client) (under "Network")

### 3. File Organization (Recommended)
- [ ] In Xcode, rename files to remove prefixes:
  - `ModelsAlertTheme.swift` → `AlertTheme.swift`
  - `ServicesCalendarService.swift` → `CalendarService.swift`
  - etc.
- [ ] Create folder groups in Xcode:
  - [ ] Models/ (move all Model files here)
  - [ ] Services/ (move all Service files here)
  - [ ] Views/ (move all View files here)
  - [ ] App/ (move AppDelegate and main app file here)

### 4. Clean Up Legacy Files
- [ ] Delete `ContentView.swift` (not used)
- [ ] Delete `Item.swift` (not used)

## 🔨 Building

- [ ] Clean Build Folder: ⌘ + Shift + K
- [ ] Build: ⌘ + B
- [ ] Run: ⌘ + R

## 🧪 First Launch Testing

### Grant Access
- [ ] App launches (you should see bell icon in menu bar)
- [ ] macOS prompts for Calendar access
- [ ] Grant access

### Verify Menu Bar
- [ ] Click bell icon
- [ ] Dropdown appears
- [ ] If you have upcoming events, they should be listed
- [ ] If not, you see "No upcoming events"

### Test Settings
- [ ] Click Settings from menu
- [ ] Settings window opens with 3 tabs:
  - [ ] General tab loads
  - [ ] Calendars tab shows your calendars
  - [ ] Appearance tab shows theme editor

### Create Test Event
- [ ] Open macOS Calendar app
- [ ] Create a new event starting **2 minutes from now**
- [ ] Make it a normal event (not all-day)
- [ ] Save it
- [ ] Wait for the start time...
- [ ] **Full-screen alert should appear!**
- [ ] Press Escape or click X to dismiss

### Test Custom Reminder
- [ ] Click bell icon → Add Full Screen Reminder
- [ ] Enter title: "Test Reminder"
- [ ] Set date/time **2 minutes from now**
- [ ] Save
- [ ] Wait...
- [ ] Alert should appear with "Custom Reminder" label

### Test Theme Editor
- [ ] Settings → Appearance
- [ ] Select a calendar from dropdown
- [ ] Click on "Event Title" element
- [ ] Change the color (try green)
- [ ] Click "Preview Full Screen"
- [ ] Full-screen preview appears
- [ ] Title should be green
- [ ] Dismiss with Escape
- [ ] Click "Save"
- [ ] Create a test event to see the new theme in action

### Test Pause
- [ ] Click bell icon
- [ ] Click "Pause Full Screen Reminders"
- [ ] Bell icon changes to `bell.slash`
- [ ] Create an event starting now
- [ ] **No alert should appear** (working as expected!)
- [ ] Unpause
- [ ] Icon returns to normal bell

## ✅ Everything Works?

If all checkboxes above are checked, your app is **fully functional**!

## ❌ Something Broken?

### Compilation Errors
→ Check TROUBLESHOOTING.md section 1

### Calendar Access Denied
→ Check TROUBLESHOOTING.md section 2

### Alert Doesn't Appear
→ Check TROUBLESHOOTING.md section 4

### General Issues
→ See TROUBLESHOOTING.md for comprehensive diagnostics

## 📚 Documentation Quick Links

- **SETUP.md** - Detailed setup instructions
- **PROJECT_STATUS.md** - What was implemented and current status
- **ARCHITECTURE.md** - Complete technical documentation
- **TROUBLESHOOTING.md** - Common issues and solutions
- **PRD** - Original product requirements

## 🎯 Next Steps After Testing

1. **Customize Default Theme**:
   - Settings → Appearance → "Default Style"
   - Adjust to your visual preferences
   - This applies to all calendars without custom themes

2. **Enable Launch at Login**:
   - Should be enabled by default
   - Verify in Settings → General
   - Check System Settings → General → Login Items

3. **Set Up Your Calendars**:
   - Settings → Calendars
   - Deselect any calendars you don't want alerts for
   - Events from deselected calendars won't trigger alerts

4. **Create Per-Calendar Themes** (Optional):
   - Settings → Appearance
   - Select a specific calendar
   - Customize its theme
   - That calendar's events will use this unique style

5. **Test with Real Events**:
   - Use your actual calendar events
   - Verify timing is accurate
   - Test video conference join buttons (if you have Zoom/Meet links)

## 🚀 Ready for Daily Use

Once everything works:
- [ ] Let the app run in the background
- [ ] It will monitor your calendars continuously
- [ ] Alerts will appear at event start times
- [ ] You can pause anytime from the menu
- [ ] Customize themes as you wish

---

**Congratulations! Your ZapCal is ready to use.** 🎉

