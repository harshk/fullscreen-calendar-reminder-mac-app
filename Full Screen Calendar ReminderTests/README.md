# Full Screen Calendar Reminder for macOS

A menu bar application that displays unmissable, full-screen alerts for your calendar events.

## Features

- 🔔 **Full-screen alerts** that appear on all displays when calendar events start
- 📅 **Calendar integration** with EventKit - syncs with all your macOS calendars
- 🎨 **Fully customizable appearance** - visual theme editor for per-calendar styling
- ⏰ **Custom reminders** - create one-off full-screen reminders
- 🎥 **Video conference quick-join** - one-click to join Zoom, Teams, Meet, etc.
- 🚫 **Pause mode** - temporarily disable alerts without unsubscribing
- 🎯 **Smart queueing** - handles multiple simultaneous events gracefully
- 🖥️ **Multi-display support** - alerts appear on all connected screens
- 🌙 **Menu bar only** - no dock icon, stays out of your way

## Requirements

- macOS 13.0 (Ventura) or later
- Calendar access permission
- Xcode 15.0+ (for building)

## Setup Instructions

### 1. Configure Entitlements

The app requires calendar access. Make sure your project includes the following entitlement:

```xml
<key>com.apple.security.personal-information.calendars</key>
<true/>
```

### 2. Add Privacy Usage Description

Add this to your `Info.plist`:

```xml
<key>NSCalendarsUsageDescription</key>
<string>Full Screen Calendar Reminder needs access to your calendars to display full-screen alerts for your events.</string>
```

### 3. Configure Launch at Login (Optional)

For launch-at-login functionality, ensure your app is properly sandboxed and signed.

### 4. Build and Run

1. Open the project in Xcode
2. Select your development team
3. Build and run (⌘R)
4. Grant calendar permission when prompted
5. The app will appear in your menu bar with a bell icon

## Architecture

The app follows a clean architecture pattern with clear separation of concerns:

### Models
- **AlertTheme** - Complete theme configuration with element styles
- **CalendarEvent** - Wrapper around EventKit events
- **CustomReminder** - SwiftData model for user-created reminders
- **AppSettings** - User preferences managed via UserDefaults

### Services
- **CalendarService** - EventKit integration and event management
- **ThemeService** - Theme persistence and retrieval
- **AlertCoordinator** - Alert queue management and display
- **ReminderService** - Custom reminder CRUD operations

### Views
- **MenuBarView** - Main menu bar dropdown interface
- **FullScreenAlertView** - The full-screen alert overlay
- **SettingsView** - Multi-tab settings interface
  - GeneralSettingsView
  - CalendarsSettingsView
  - AppearanceSettingsView (visual theme editor)
- **ReminderViews** - Add and manage custom reminders

### App Lifecycle
- **AppDelegate** - Menu bar setup and coordination
- **Full_Screen_Calendar_ReminderApp** - Main app entry point with SwiftData container

## Key Design Decisions

### 1. Theme System
The entire alert appearance is driven by a `AlertTheme` model that is fully `Codable`. This allows:
- Per-calendar customization
- Easy persistence
- Future import/export capabilities
- No hardcoded UI values

### 2. Alert Display
Alerts use `NSWindow` at `.screenSaver` level with `.canJoinAllSpaces` and `.fullScreenAuxiliary` behaviors to overlay all apps, including full-screen applications.

### 3. Event Polling
Events are polled every 5 minutes and on calendar database changes. A set of fired event IDs prevents duplicate alerts.

### 4. Queue Behavior
Multiple simultaneous events are queued and displayed sequentially. Users must dismiss each alert individually.

## Testing

The project includes comprehensive unit tests using Swift Testing:

```bash
# Run tests
cmd+U in Xcode
```

Test coverage includes:
- Theme model serialization
- Custom reminder logic
- Calendar event processing
- Alert coordinator queue management
- Settings persistence

## Configuration

### Adjusting Polling Interval

The default polling interval is 5 minutes. To change it, modify `CalendarService.swift`:

```swift
pollingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) // Change 300 to desired seconds
```

### Adding Video Conference Patterns

To support additional video conference services, update `CalendarEvent.extractVideoConferenceURL()`:

```swift
let patterns = [
    "zoom.us",
    "meet.google.com",
    "teams.microsoft.com",
    "webex.com",
    "facetime://",
    "your.custom.service" // Add here
]
```

## Troubleshooting

### Calendar Permission Issues
If the app doesn't request calendar permission:
1. Check that `NSCalendarsUsageDescription` is in Info.plist
2. Verify calendar entitlement is enabled
3. Reset permissions: `tccutil reset Calendar`

### Alerts Not Appearing
1. Check that calendars are selected in Settings
2. Verify alerts are not paused (menu bar icon should not have a slash)
3. Ensure events are not marked as "All Day" or "Declined"

### Launch at Login Not Working
1. Verify app is properly signed
2. Check sandboxing is enabled
3. Ensure `SMAppService` permission in entitlements

## Future Enhancements

See the PRD for planned v2.0 features:
- Advance alert timing (X minutes before events)
- Sound alerts
- Snooze functionality
- Named themes with import/export
- Global keyboard shortcuts
- Menubar badge count
- macOS widgets

## License

[Your License Here]

## Credits

Built with Swift, SwiftUI, EventKit, and SwiftData.
