# Developer Quick Reference

## Common Tasks

### Adding a New Alert Element

1. **Add to enum** (`Models/AlertTheme.swift`):
```swift
enum AlertElementIdentifier: String, Codable, CaseIterable {
    // ... existing cases
    case myNewElement
}
```

2. **Add default style** (`AlertTheme.defaultTheme()`):
```swift
.myNewElement: AlertElementStyle(
    fontFamily: "SF Pro",
    fontSize: 24,
    fontWeight: .regular,
    fontColor: CodableColor(.white),
    textAlignment: .center,
    positionX: 0.5,
    positionY: 0.6,
    maxWidthPercentage: 0.8
)
```

3. **Render in alert** (`Views/AlertView/FullScreenAlertView.swift`):
```swift
if let style = theme.elementStyles[.myNewElement] {
    styledText(
        text: myContent,
        style: style,
        geometry: geometry
    )
}
```

4. **Add to theme editor** (`Views/SettingsView/AppearanceSettingsView.swift`):
```swift
private func iconForElement(_ element: AlertElementIdentifier) -> String {
    // ... existing cases
    case .myNewElement: return "star.fill"
}

private func labelForElement(_ element: AlertElementIdentifier) -> String {
    // ... existing cases
    case .myNewElement: return "My Element"
}
```

### Adding a New Setting

1. **Add to AppSettings** (`Models/AppSettings.swift`):
```swift
@Published var myNewSetting: Bool {
    didSet {
        UserDefaults.standard.set(myNewSetting, forKey: "myNewSetting")
    }
}

private init() {
    // ...
    self.myNewSetting = UserDefaults.standard.object(forKey: "myNewSetting") as? Bool ?? false
}
```

2. **Add UI control** (`Views/SettingsView/GeneralSettingsView.swift`):
```swift
Toggle("My New Setting", isOn: $settings.myNewSetting)
```

3. **Use the setting**:
```swift
if AppSettings.shared.myNewSetting {
    // Do something
}
```

### Adding a New Video Conference Service

**Update pattern matching** (`Models/CalendarEvent.swift`):
```swift
let patterns = [
    "zoom.us",
    "meet.google.com",
    // ... existing
    "mynewservice.com"  // Add here
]
```

### Changing Polling Intervals

**Calendar events** (`Services/CalendarService.swift`):
```swift
pollingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) // 5 minutes
```

**Custom reminders** (`Services/ReminderService.swift`):
```swift
pollingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) // 1 minute
```

### Changing Alert Window Level

**Adjust window priority** (`Services/AlertCoordinator.swift`):
```swift
window.level = .screenSaver  // Options: .normal, .floating, .statusBar, .popUpMenu, .screenSaver
```

### Adding a New Theme Property

1. **Update AlertElementStyle** (`Models/AlertTheme.swift`):
```swift
struct AlertElementStyle: Codable, Equatable {
    // ... existing properties
    var myNewProperty: CGFloat?
}
```

2. **Update default theme**:
```swift
.title: AlertElementStyle(
    // ... existing properties
    myNewProperty: 10
)
```

3. **Use in view**:
```swift
.padding(style.myNewProperty ?? 10)
```

4. **Add editor control** (`Views/SettingsView/AppearanceSettingsView.swift`):
```swift
Stepper(
    "My Property: \(Int(style.myNewProperty ?? 10))",
    value: Binding(
        get: { style.myNewProperty ?? 10 },
        set: { newValue in
            style.myNewProperty = newValue
            workingTheme.elementStyles[element] = style
        }
    ),
    in: 0...100
)
```

## Service Access Patterns

### Calendar Service
```swift
// Access
let service = CalendarService.shared

// Check access
if service.hasAccess {
    // Use calendar features
}

// Request access
try await service.requestAccess()

// Get events
await service.fetchUpcomingEvents()
let events = service.upcomingEvents

// Open event
service.openEventInCalendarApp(event)
```

### Theme Service
```swift
let service = ThemeService.shared

// Get theme
let theme = service.getTheme(for: calendarID)
let defaultTheme = service.getTheme(for: nil)

// Save theme
service.setTheme(customTheme, for: calendarID)

// Reset
service.resetTheme(for: calendarID)

// Duplicate
service.duplicateTheme(from: sourceID, to: targetID)
```

### Alert Coordinator
```swift
let coordinator = AlertCoordinator.shared

// Queue alert
coordinator.queueAlert(for: event)
coordinator.queueAlert(for: reminder)

// Preview
coordinator.showPreviewAlert(theme: myTheme)

// Check state
if coordinator.isShowingAlert {
    // Alert visible
}
```

### Reminder Service
```swift
let service = ReminderService.shared

// Setup (call once)
service.setModelContext(context)

// CRUD
try service.addReminder(title: "Title", scheduledDate: date)
try service.updateReminder(reminder, title: "New", scheduledDate: newDate)
try service.deleteReminder(reminder)

// Access
let upcoming = service.upcomingReminders
let past = service.pastReminders
```

### App Settings
```swift
let settings = AppSettings.shared

// Access
settings.launchAtLogin = true
settings.numberOfEventsInMenuBar = 20
settings.isPaused = true
settings.selectedCalendarIdentifiers.insert(calendarID)

// Observe
@ObservedObject var settings = AppSettings.shared
```

## Common SwiftUI Patterns

### Opening Settings
```swift
@State private var showingSettings = false

Button("Settings") {
    showingSettings = true
}
.sheet(isPresented: $showingSettings) {
    SettingsView()
}
```

### Color from Hex
```swift
Color(hex: "#FF1493")
```

### Color to Hex
```swift
let hexString = myColor.toHex()
```

### Codable Color
```swift
let codable = CodableColor(Color.red)
let color = codable.color
```

## Testing Utilities

### Create Mock Event
```swift
let event = CalendarEvent.mock(
    title: "Test",
    startDate: Date(),
    calendarTitle: "Work",
    calendarColor: "#FF1493",
    location: "Office",
    videoConferenceURL: URL(string: "https://zoom.us/j/123")
)
```

### Create Test Reminder
```swift
let reminder = CustomReminder(
    title: "Test",
    scheduledDate: Date().addingTimeInterval(3600)
)
```

### Create Test Theme
```swift
let theme = AlertTheme.defaultTheme(id: "test", name: "Test Theme")
```

## Debugging Tips

### Check Calendar Events
```swift
print("Upcoming events: \(CalendarService.shared.upcomingEvents.count)")
for event in CalendarService.shared.upcomingEvents {
    print("- \(event.title) at \(event.startDate)")
}
```

### Check Themes
```swift
print("Themes: \(ThemeService.shared.themes.keys)")
let theme = ThemeService.shared.getTheme(for: "default")
print("Default theme elements: \(theme.elementStyles.keys)")
```

### Check Alert Queue
```swift
print("Queue size: \(AlertCoordinator.shared.alertQueue.count)")
print("Showing alert: \(AlertCoordinator.shared.isShowingAlert)")
```

### Check Settings
```swift
print("Launch at login: \(AppSettings.shared.launchAtLogin)")
print("Paused: \(AppSettings.shared.isPaused)")
print("Selected calendars: \(AppSettings.shared.selectedCalendarIdentifiers)")
```

### Force Alert Display (for testing)
```swift
let testEvent = CalendarEvent.mock(title: "Test Alert")
AlertCoordinator.shared.queueAlert(for: testEvent)
```

## Console Filters

In Console.app, filter by these terms:

- `Full Screen Calendar` - All app logs
- `EventKit` - Calendar access logs
- `NSWindow` - Window management
- `Error` - Only errors

## Common Error Messages

| Error | Solution |
|-------|----------|
| "Could not create ModelContainer" | Check SwiftData schema, delete app data |
| "Calendar access denied" | Grant permission in System Settings |
| "Theme not found" | Run `ThemeService.shared.loadThemes()` |
| "Window not appearing" | Check window level and collection behavior |
| "Events not loading" | Check calendar permission and selected calendars |

## Performance Profiling

### Memory Leaks
1. Run in Instruments (Product → Profile)
2. Choose "Leaks" template
3. Trigger alerts and check for leaked NSWindow instances

### Time Profiler
1. Choose "Time Profiler" template
2. Exercise all features
3. Look for hot paths in event fetching and theme rendering

### SwiftUI Performance
- Use `Self._printChanges()` in views to debug unnecessary redraws
- Check for @Published properties triggering too often

## File Organization

When adding new files:

```
Models/           → Data structures, always Codable
Services/         → @MainActor classes with @Published properties
Views/
  FeatureName/    → Group related views in folders
    MainView.swift
    SubView.swift
Tests/           → Mirror the main structure
```

## Code Style

### Naming
- Services: `XxxxxService` (e.g., `CalendarService`)
- Views: `XxxxxView` (e.g., `SettingsView`)
- Models: Noun (e.g., `AlertTheme`, `CalendarEvent`)

### Access Control
- Use `private` for internal implementation
- Use `@MainActor` for UI-touching code
- Use `private(set)` for read-only published properties

### Error Handling
```swift
do {
    try await service.performAction()
} catch {
    print("Failed to perform action: \(error)")
    // Show user-facing error
}
```

## Build & Run Checklist

Before committing:
- [ ] Code builds without warnings
- [ ] All tests pass (⌘ + U)
- [ ] App launches and menu bar appears
- [ ] Can create and dismiss alert
- [ ] Settings open and save
- [ ] No memory leaks in Instruments

## Deployment Checklist

Before releasing:
- [ ] Increment version number
- [ ] Update changelog
- [ ] Test on clean macOS install
- [ ] Test with no calendars
- [ ] Test with 100+ calendars
- [ ] Test multi-monitor setup
- [ ] Run full test suite
- [ ] Check code signing
- [ ] Notarize build
- [ ] Test DMG installation

## Useful Xcode Shortcuts

- `⌘ + R` - Build and run
- `⌘ + U` - Run tests
- `⌘ + .` - Stop
- `⌘ + B` - Build
- `⌘ + Shift + K` - Clean build
- `⌘ + Option + Shift + K` - Clean derived data
- `⌘ + Shift + O` - Quick open

## Git Workflow

```bash
# Feature branch
git checkout -b feature/my-feature

# Commit
git add .
git commit -m "Add feature: description"

# Push
git push origin feature/my-feature

# Merge to main
git checkout main
git merge feature/my-feature
```

## Resources

- [EventKit Documentation](https://developer.apple.com/documentation/eventkit)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)

---

Keep this file updated as the project evolves!
