# ZapCal - Project Structure

## Overview
This document outlines the complete architecture and file organization of the ZapCal macOS application.

## Directory Structure

```
ZapCal/
├── App/
│   ├── Full_Screen_Calendar_ReminderApp.swift  # Main app entry point
│   ├── AppDelegate.swift                        # Menu bar management
│   └── ContentView.swift                        # Legacy view (unused)
│
├── Models/
│   ├── AlertTheme.swift        # Theme configuration model
│   ├── CalendarEvent.swift     # EventKit wrapper
│   ├── CustomReminder.swift    # SwiftData reminder model
│   └── AppSettings.swift       # User preferences
│
├── Services/
│   ├── CalendarService.swift   # EventKit integration
│   ├── ThemeService.swift      # Theme management
│   ├── AlertCoordinator.swift  # Alert queue & display
│   └── ReminderService.swift   # Custom reminder CRUD
│
├── Views/
│   ├── AlertView/
│   │   └── FullScreenAlertView.swift
│   │
│   ├── MenuBarView/
│   │   └── MenuBarView.swift
│   │
│   ├── ReminderViews/
│   │   ├── AddReminderView.swift
│   │   └── ManageRemindersView.swift
│   │
│   └── SettingsView/
│       ├── SettingsView.swift
│       ├── GeneralSettingsView.swift
│       ├── CalendarsSettingsView.swift
│       └── AppearanceSettingsView.swift
│
├── Resources/
│   ├── Info.plist.template
│   └── Full_Screen_Calendar_Reminder.entitlements.template
│
└── Tests/
    ├── Full_Screen_Calendar_ReminderTests.swift
    └── Full_Screen_Calendar_ReminderUITests.swift
```

## Component Responsibilities

### App Layer

#### `Full_Screen_Calendar_ReminderApp.swift`
- Main entry point with `@main` attribute
- SwiftData model container setup
- App lifecycle management
- No visible windows (menu bar only)

#### `AppDelegate.swift`
- NSApplicationDelegate implementation
- Status bar item creation and management
- Popover setup for menu bar dropdown
- Icon state updates (paused/active)
- Model context injection

### Models Layer

#### `AlertTheme.swift`
**Purpose:** Complete theme configuration system
- `AlertTheme`: Main theme structure with background and element styles
- `AlertElementStyle`: Per-element configuration (fonts, colors, positions)
- `AlertElementIdentifier`: Enum of all themeable elements
- `CodableColor`: Color wrapper for persistence
- `BackgroundType`: Solid color or image background options

**Key Features:**
- Fully Codable for persistence
- Default factory methods
- Support for custom fonts, colors, positions
- Button-specific properties for join/dismiss buttons

#### `CalendarEvent.swift`
**Purpose:** Wrapper around EventKit's EKEvent
- Simplified event representation
- Video conference URL extraction
- Participation status handling
- Calendar color extraction
- Mock factory for testing/previews

**Key Logic:**
- `shouldTriggerAlert`: Excludes all-day and declined events
- `extractVideoConferenceURL`: Pattern matching for Zoom, Meet, Teams, Webex

#### `CustomReminder.swift`
**Purpose:** SwiftData model for user-created reminders
- Persistent storage with SwiftData
- `hasFired` flag to prevent duplicates
- Computed `isPast` and `isUpcoming` properties

#### `AppSettings.swift`
**Purpose:** UserDefaults-backed settings
- `@Published` properties for reactive UI
- Launch at login integration with SMAppService
- Calendar selection persistence
- Pause state management
- Number of events to display

### Services Layer

#### `CalendarService.swift`
**Purpose:** EventKit integration and event management

**Key Responsibilities:**
- Calendar access authorization flow
- Event fetching with predicates
- 5-minute polling timer
- Real-time calendar change notifications
- System clock change handling
- Wake from sleep event recovery
- Event deduplication with fired IDs set

**Public API:**
```swift
func requestAccess() async throws
func loadCalendars() async
func fetchUpcomingEvents() async
func checkForEventsToFire()
func openEventInCalendarApp(_ event: CalendarEvent)
```

#### `ThemeService.swift`
**Purpose:** Theme persistence and retrieval

**Key Responsibilities:**
- Theme dictionary management (calendar ID → theme)
- UserDefaults persistence with JSON encoding
- Default theme provision
- Theme duplication and reset
- Auto-creation for new calendars

**Public API:**
```swift
func getTheme(for calendarIdentifier: String?) -> AlertTheme
func setTheme(_ theme: AlertTheme, for calendarIdentifier: String)
func resetTheme(for calendarIdentifier: String)
func duplicateTheme(from: String, to: String)
```

#### `AlertCoordinator.swift`
**Purpose:** Alert queue management and window display

**Key Responsibilities:**
- Alert queue with priority (calendar events before custom reminders)
- Multi-screen window creation
- NSWindow management at .screenSaver level
- Escape key monitoring
- Queue position tracking
- Preview mode for theme testing

**Alert Window Configuration:**
- Level: `.screenSaver`
- Behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`
- Style: Borderless, non-activating
- Content: SwiftUI via NSHostingView

#### `ReminderService.swift`
**Purpose:** Custom reminder CRUD operations

**Key Responsibilities:**
- SwiftData context management
- Reminder fetch and filtering
- CRUD operations
- 1-minute polling for due reminders
- Integration with AlertCoordinator

### Views Layer

#### `MenuBarView.swift`
**Purpose:** Main popover content for menu bar dropdown

**Features:**
- Upcoming events list grouped by day
- Calendar access status display
- Event rows with time, title, location
- Video conference quick-join buttons
- Action menu (add/manage reminders, pause, settings, quit)
- Empty states for no events/no access

#### `FullScreenAlertView.swift`
**Purpose:** Full-screen alert overlay rendering

**Features:**
- Theme-driven layout (no hardcoded positions/colors)
- Background support (solid color or image)
- Dynamic element positioning from theme
- Primary vs secondary screen differentiation
- Queue counter display
- Join meeting button
- Dismiss button

**Architecture:**
- Accepts `AlertTheme` as single source of truth
- Uses GeometryReader for percentage-based positioning
- Renders all elements from `elementStyles` dictionary

#### `AddReminderView.swift` & `ManageRemindersView.swift`
**Purpose:** Custom reminder management

**Features:**
- Add: Title, date, time pickers with validation
- Manage: List view with upcoming/past sections
- Edit: Inline editing with same validation
- Delete: Confirmation dialogs
- Form validation (title required, max 200 chars, future date)

#### `SettingsView.swift`
**Purpose:** Tabbed settings interface

**Tabs:**
1. **General**: Launch at login, event count, pause behavior info
2. **Calendars**: Account-grouped calendar list with toggles
3. **Appearance**: Visual theme editor (most complex)

#### `AppearanceSettingsView.swift`
**Purpose:** Visual theme editor

**Features:**
- Split view: Preview pane | Editor pane
- Calendar selector dropdown
- Live preview at 40% scale
- Element selector grid
- Per-element property inspector:
  - Font family, size, weight
  - Color picker
  - Text alignment
  - X/Y position sliders (percentage-based)
  - Max width slider
  - Button-specific: background, text color, corner radius, padding
  - Icon-specific: size, color
- Background properties:
  - Type toggle (solid/image)
  - Image picker (PNG, JPEG, WebP)
  - Overlay color and opacity
- Actions:
  - Preview full screen
  - Duplicate from another calendar
  - Reset to defaults
  - Save/revert

**Technical Details:**
- Works with `@State var workingTheme` for editing
- Saves to `ThemeService` on demand
- Image data embedded in theme (survives file moves)

## Data Flow

### Startup Sequence
1. App launches with AppDelegate
2. Hide dock icon (`setActivationPolicy(.accessory)`)
3. Create status bar item
4. Request calendar access
5. Load calendars and auto-select all
6. Start polling timers (CalendarService + ReminderService)
7. Check for events to fire

### Alert Flow
1. Timer fires or calendar change detected
2. Service checks for events at current time
3. Filter out fired events (by ID)
4. Create `AlertItem` enum wrapper
5. Queue in `AlertCoordinator`
6. Display on all screens with themed layout
7. User dismisses → remove from queue → show next

### Theme Customization Flow
1. User opens Settings → Appearance
2. Select calendar from dropdown
3. Load existing theme or create from default
4. Edit in inspector with live preview
5. Click "Preview Full Screen" for actual-size test
6. Save → persist to UserDefaults via ThemeService
7. Next alert for that calendar uses new theme

### Custom Reminder Flow
1. User clicks "Add ZapCal Reminder" in menu
2. Fill form with title, date, time
3. Validate (future date, non-empty title)
4. Save to SwiftData
5. ReminderService polls every minute
6. When time matches, create AlertItem
7. Queue in AlertCoordinator (after calendar events)
8. Display with "Custom Reminder" label

## Key Patterns

### Singleton Services
All services are singletons accessed via `.shared`:
- CalendarService
- ThemeService
- AlertCoordinator
- ReminderService
- AppSettings

Rationale: Single source of truth, easy access from any view

### ObservableObject + @Published
Services and settings use Combine for reactive updates:
```swift
@ObservedObject var calendarService = CalendarService.shared
```

### Swift Concurrency
Async/await used throughout for:
- Calendar access requests
- Event fetching
- Loading calendars
- Main actor isolation for UI updates

### SwiftData
Used exclusively for CustomReminder persistence:
- Simple CRUD with FetchDescriptor
- Model context injected from AppDelegate
- Query in ReminderService

### UserDefaults
Used for:
- AppSettings properties
- Theme dictionary (JSON encoded)
- Fired event IDs are in-memory only (cleared on restart)

### Codable Everywhere
All models are Codable for:
- Theme persistence
- Easy serialization
- Future import/export

## Testing Strategy

### Unit Tests
- Model serialization (Codable conformance)
- Custom reminder logic (isPast, isUpcoming)
- Calendar event processing
- Theme service CRUD
- Alert coordinator queue management

### UI Tests
- Menu bar interaction
- Settings navigation
- Reminder creation flow
- Calendar selection

## Performance Considerations

### Polling Intervals
- Calendar events: 5 minutes (balance between freshness and battery)
- Custom reminders: 1 minute (acceptable for one-off events)

### Event Deduplication
- In-memory Set of fired IDs
- Cleared on app restart (intended behavior)
- Prevents duplicate alerts during polling overlap

### Image Storage
- Embedded in theme as Data
- Survives source file deletion
- Trade-off: Larger UserDefaults, but more reliable

### Window Management
- Windows created on demand per alert
- Cleaned up immediately after dismissal
- One window per screen per alert

## Error Handling

### Calendar Access Denied
- Show banner in menu bar dropdown
- Link to System Settings
- Custom reminders still functional

### No Calendars Selected
- Warning banner in settings
- Menu bar shows "no calendars" message
- Graceful degradation

### Event Deleted Mid-Queue
- Re-fetch on display
- Skip silently if missing
- Advance to next in queue

### System Sleep/Wake
- Re-poll on wake
- Fire events from last 2 minutes
- Skip older events

### Clock Changes
- Listen for NSSystemClockDidChangeNotification
- Recalculate all alert times
- Clear fired IDs

## Future Architecture Notes

### Scalability for v2.0 Features
The architecture is designed to easily support:

**Named Themes:**
- Already has theme duplication
- Just need UI for naming and theme library

**Import/Export:**
- Themes are Codable
- Can serialize to file immediately

**Advance Alerts:**
- Add `alertOffset` to settings
- Modify fire condition in services

**Snooze:**
- Add button to alert view
- Re-queue with adjusted time

**Sounds:**
- Add audio file to theme
- Play on alert display

## Dependencies

### System Frameworks
- SwiftUI: All UI
- EventKit: Calendar integration
- SwiftData: Custom reminder persistence
- AppKit: NSWindow, NSStatusItem, NSWorkspace
- ServiceManagement: SMAppService for login item

### No Third-Party Dependencies
All functionality implemented with system frameworks for:
- App Store compliance
- Long-term maintainability
- Reduced attack surface

## Build Configuration

### Deployment Target
- macOS 13.0 (Ventura)
- Uses latest Swift concurrency features
- SMAppService (replaces deprecated APIs)

### Entitlements Required
- App Sandbox: YES
- Calendar access
- User-selected file read/write (for image picker)
- Network client (for opening video URLs)

### Info.plist Keys
- `NSCalendarsUsageDescription`
- `LSUIElement` = YES (hide dock icon)
- `LSMinimumSystemVersion` = 13.0

---

This architecture provides a solid foundation for the v1.0 requirements while remaining extensible for future enhancements.
