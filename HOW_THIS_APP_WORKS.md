# How ZapCal Works

ZapCal is a macOS menu bar application that displays customizable full-screen alerts and mini banner notifications for upcoming calendar events, Apple Reminders, and custom in-app reminders. Built with SwiftUI, it integrates with EventKit for calendar/reminder access and uses SwiftData for custom reminder persistence.

---

## Table of Contents

1. [App Lifecycle & Entry Point](#1-app-lifecycle--entry-point)
2. [Menu Bar Panel](#2-menu-bar-panel)
3. [Event & Reminder Fetching](#3-event--reminder-fetching)
4. [Alert Firing Logic](#4-alert-firing-logic)
5. [Alert Merge Buffer](#5-alert-merge-buffer)
6. [Full-Screen Alert Display](#6-full-screen-alert-display)
7. [Mini (Pre-Alert) Banner Display](#7-mini-pre-alert-banner-display)
8. [Event Alarm Alerts](#8-event-alarm-alerts)
9. [Snooze System](#9-snooze-system)
10. [Dismiss & Disable Behavior](#10-dismiss--disable-behavior)
11. [Sleep & Wake Handling](#11-sleep--wake-handling)
12. [Custom Reminders](#12-custom-reminders)
13. [Apple Reminders Integration](#13-apple-reminders-integration)
14. [Alert Themes & Presets](#14-alert-themes--presets)
15. [Theme Assignment to Calendars](#15-theme-assignment-to-calendars)
16. [Alert Configurations](#16-alert-configurations)
17. [Settings](#17-settings)
18. [Welcome & Onboarding Flow](#18-welcome--onboarding-flow)
19. [Pause / Resume](#19-pause--resume)
20. [Deduplication Strategies](#20-deduplication-strategies)
21. [Persistence & Storage](#21-persistence--storage)
22. [Memory & Performance](#22-memory--performance)
23. [Video Conference URL Detection](#23-video-conference-url-detection)
24. [Migration Logic](#24-migration-logic)
25. [Free Trial & In-App Purchase](#25-free-trial--in-app-purchase)
26. [About ZapCal Screen](#26-about-zapcal-screen)
27. [File & Code Organization](#27-file--code-organization)

---

## 1. App Lifecycle & Entry Point

**Files**: `Full_Screen_Calendar_ReminderApp.swift`, `AppDelegate.swift`

### Startup Sequence

1. **SwiftUI App** (`Full_Screen_Calendar_ReminderApp`) initializes:
   - Sets up SwiftData `ModelContainer` for `CustomReminder` persistence
   - Registers all bundled fonts (TTF/OTF files from the app bundle)
   - Delegates to `AppDelegate` via `@NSApplicationDelegateAdaptor`

2. **AppDelegate.applicationDidFinishLaunching()**:
   - Creates `NSStatusItem` in the system menu bar with a custom `StatusBarIcon`
   - Initializes all services: `CalendarService`, `ReminderService`, `AppleRemindersService`, `AlertCoordinator`, `PreAlertManager`, `ThemeService`
   - Runs any pending migrations (e.g., SubtleToMiniMigration)
   - Checks if welcome/onboarding has been completed; shows welcome window if not
   - Sets app activation policy to `.accessory` (no dock icon, menu bar only)
   - Registers global and local event monitors for panel dismissal

### Activation Policy

- **`.accessory`**: Default state. App is menu-bar-only, no dock icon.
- **`.regular`**: Temporarily set when settings window, manage reminders window, welcome screen, or About window is shown (makes dock icon appear so windows are interactable). Also set temporarily during IAP purchase flow (required for StoreKit sheet).
- Toggled back to `.accessory` when all windows close.

---

## 2. Menu Bar Panel

**File**: `ViewsMenuBarViewMenuBarView.swift`, `AppDelegate.swift`

### Panel Architecture

- Uses `NSPanel` (not `NSPopover`) to avoid the system popover caret arrow
- Panel dimensions: **350px wide x 500px tall** (scrollable)
- Uses `NSVisualEffectView` with `.menu` material and `.behindWindow` blending for translucent glass effect that blends with the desktop wallpaper
- Panel is positioned flush against the bottom of the menu bar, aligned to the status item icon edge

### Panel Content

- **Header**: "ZapCal v{version}" label + settings gear icon button
- **Event list**: Combined list of calendar events, custom reminders, and Apple Reminders
  - Sorted by start date
  - Calendar events show: calendar color circle, calendar name, time, event title
  - Custom reminders show: orange bell icon, time, reminder title
  - Apple Reminders show: reminder list name, time, title
  - Limited to `numberOfEventsInMenuBar` items (default 50, max 99)
- **Actions**: "Add ZapCal Reminder" button, "Manage Reminders" button, "Open Settings", "About ZapCal"
- **Disabled events**: Events with alerts disabled are shown at 40% opacity (dimmed). Right-click context menu offers "Re-enable alerts" / "Disable alerts" toggle.
- **Empty states**: Message for no calendar access or no calendars selected

### Panel Show/Dismiss

- **Show**: Click menu bar icon toggles panel visibility
- **Dismiss**: Click menu bar icon again, click outside panel, press Escape, or open settings/other windows
- Global and local `NSEvent` monitors detect clicks outside the panel to dismiss it

### Right-Click Menu

Right-clicking the menu bar icon shows:
- "Pause all ZapCal Alerts" / "Resume ZapCal Alerts"
- "Settings"
- Separator
- "About ZapCal"
- "Quit"

When the trial is expired, only "Free Trial Expired" (disabled) and "Quit" are shown.

---

## 3. Event & Reminder Fetching

### Calendar Events (CalendarService)

**File**: `ServicesCalendarService.swift`

- **Fetch timer**: Runs every **30 seconds** to query EventKit for upcoming events
- **Query window**: From now to **1 year ahead**
- **Background execution**: EventKit queries run on `.userInitiated` priority background thread

**Filtering**:
- Excludes declined events (checks `participationStatus`)
- All-day events are **included** in the menu bar list (they are not filtered out)
- Deduplicates recurring Google Calendar events using composite key: `eventIdentifier + "_" + startDateTimestamp`
- Only includes events from user-selected calendars (`selectedCalendarIdentifiers`)

**Stale ID Pruning**:
- During each fetch, compares current event IDs from EventKit with stored `firedEventIDs`
- Any ID in `firedEventIDs` that no longer appears in the current EventKit results is removed
- Prevents unbounded growth of the tracking set

### Apple Reminders (AppleRemindersService)

**File**: `ServicesAppleRemindersService.swift`

- **Fetch window**: **2 weeks** ahead
- Only fetches incomplete reminders with due dates
- Only includes reminders from user-selected reminder lists (`selectedReminderListIdentifiers`)
- Shares the same `EKEventStore` instance with CalendarService to avoid EventKit conflicts

### Custom Reminders (ReminderService)

**File**: `ServicesReminderService.swift`

- Fetches from local SwiftData store (no EventKit)
- Loads all `CustomReminder` objects where `hasFired == false`

---

## 4. Alert Firing Logic

**File**: `ServicesCalendarService.swift` (method: `checkForEventsToFire`)

The fire check runs at each **minute boundary** (synchronized to clock second = 0), coordinated by `AlertCheckCoordinator`. Each tick:

### Step 1: Sleep Detection

```
elapsed = now - lastCheckTime
if elapsed > 10 seconds:
    // System was asleep - silently mark all past events as fired
    for each event where startDate <= now:
        add to firedEventIDs (suppresses alerts)
    return (skip alert firing this tick)
```

This prevents a storm of alerts for events that occurred while the Mac was asleep.

### Step 2: Config-Based Alert Firing

For each enabled `AlertConfig` in `AppSettings.shared.alertConfigs`:

```
for each upcoming event:
    if event.isAllDay AND NOT allDayEventAlertsEnabled: skip
    timeUntilStart = event.startDate - now

    if timeUntilStart <= config.leadTime AND timeUntilStart > -120 seconds:
        if event.id NOT in firedEventIDs AND event.id NOT in alertFiredIDs[config.id]:
            FIRE ALERT for this event with this config's style
            add event.id to alertFiredIDs[config.id]
```

Key points:
- **Lead time**: Each config has its own lead time (e.g., mini alert fires 60s before, full-screen fires at 0s)
- **Grace period**: Events up to **120 seconds (2 minutes)** past their start time can still trigger alerts
- **Per-config tracking**: `alertFiredIDs` is keyed by config ID, so each config fires independently for each event
- **Global disable**: `firedEventIDs` blocks ALL configs from firing for that event (used by "Disable alerts" action)

### Step 3: Submit to Merge Buffer

Instead of showing alerts immediately, fired alerts are submitted to `AlertMergeBuffer.shared.submit()` which batches simultaneous alerts (see section 5).

---

## 5. Alert Merge Buffer & Minute-Boundary Checks

**Files**: `AlertMergeBuffer.swift`, `ServicesAlertCheckCoordinator.swift`

### Purpose

When multiple events start at the same time (e.g., two meetings at 10:00 AM), the merge buffer coalesces them into a single merged alert instead of showing them one by one.

### Synchronized Minute-Boundary Checks

The `AlertCheckCoordinator` fires checks at minute boundaries (synchronized to clock second = 0):

1. Each minute boundary calls `tick()` which invokes all three services' check methods sequentially (CalendarService, ReminderService, AppleRemindersService)
2. Immediately calls `AlertMergeBuffer.shared.flush()` after all services have reported
3. Reschedules the next check for the start of the next minute

This deterministic timing eliminates the old 10-second merge window, ensuring all simultaneous alerts are collected and flushed together in a single coordinated pass.

### Flush Logic

1. **Deduplication**: Pending items are deduped by ID
2. **Style resolution**: If ANY pending alert is full-screen, the merged result is full-screen. Otherwise mini.
3. **Single alert**: If only 1 item pending, fires normally (no merging)
4. **Multiple alerts**: Creates a merged alert:
   - Displays the first **3 event titles** as bullet points
   - Shows "and X more" if more than 3 events
   - Uses the **earliest start date** among all merged events
   - For full-screen: creates `AlertItem.merged(titles:overflowCount:startDate:sourceItems:)`
   - For mini: calls `PreAlertManager.showMergedBanner()`

---

## 6. Full-Screen Alert Display

**File**: `ServicesAlertCoordinator.swift`, `ViewsAlertViewFullScreenAlertView.swift`

### Window Architecture

- One `NSPanel` per connected screen (covers all displays)
- Window level: **`.screenSaver`** (highest level, above everything including the dock)
- Borderless, full-size content, non-activating panel
- Custom `KeyablePanel` subclass that can receive key events even when app is inactive
- Custom `FirstClickHostingView` that accepts the first mouse click and forces app activation

### Alert Queue

- Alerts are held in a queue sorted by `startDate`
- Only one alert displays at a time
- When dismissed/snoozed, the next alert in queue is shown
- Queue position is displayed on the alert (e.g., "1 of 3")

### Alert Content (Primary Screen)

- **Event title**: Large text, centered, max 2 lines with auto-shrinking
- **Time range**: "10:00 AM - 11:00 AM" format
- **Calendar name**: Prefixed with "Calendar:"
- **Location**: With map icon, clickable to open Apple Maps
- **Dismiss button**: Top-left circular X icon
- **Snooze button**: Dropdown with configurable durations (e.g., 1 min, 5 min, 15 min)
- **Join Meeting button**: Shown only if video conference URL detected (opens URL in browser)

### Alert Content (Secondary Screens)

- Simplified view: Title + time only (no buttons or details)

### Merged Alert Content

- Bullet-pointed list of up to 3 event titles
- "and X more" text for overflow
- Single dismiss/snooze controls for the entire group

### Visual Effects

- **Fade-in animation**: 1-second opacity transition
- **Background**: Solid color or blurred image with configurable overlay color
- **Image blur**: Configurable blur slider (default 30%)
- **Theme**: Fully customizable per calendar (see section 14)

### Keyboard Handling

- **Local event monitor**: Captures Escape key (keyCode 53) when app is key window (~90% of cases)
- **Global event monitor**: Fallback for when app isn't key (requires Accessibility permissions)
- Escape dismisses the current alert

---

## 7. Mini (Pre-Alert) Banner Display

**File**: `ServicesPreAlertManager.swift`, `ViewsPreAlertBannerView.swift`

### Banner Architecture

- Single reusable `NSPanel` instance (not recreated per alert)
- Dimensions: **460px wide x 108px tall** (single event), height grows for merged banners (+22px per extra line)
- Positioned at top-right of primary screen
- Floating panel level

### Banner Content

- **Event title**: Bold text
- **Countdown timer**: "Starts in X:XX" format, updates every 1 second
  - Format varies: "Starts in Xd Xh" (days), "Starts in Xh Xm" (hours), "Starts in X:XX" (minutes:seconds), or "Now"
- **Progress ring**: Circular visual indicator showing remaining time until event
- **Join Meeting button**: If video conference URL detected
- **Disable button**: "Disable alerts for this event" (adds event to firedEventIDs)

### Auto-Dismiss

- If `miniDuration > 0`: Banner auto-dismisses after the configured number of seconds (default 15)
- If `miniDuration == 0`: Banner persists until the event starts (no auto-dismiss)
- Progress ring animates the countdown

### Merged Mini Banner

- Shows bullet-pointed list of up to 3 titles
- "and X more" for overflow
- Disable button hidden on merged banners
- Height increases to accommodate extra lines

### Banner State

- `PreAlertBannerState` (ObservableObject) manages:
  - `isVisible`: Controls show/hide
  - `title`, `startDate`, `calendarColor`: Event details
  - `theme`: PreAlertTheme for styling
  - `videoConferenceURL`: For Join button
- Two rendering modes:
  1. **State-driven**: Observes PreAlertBannerState (normal operation)
  2. **Direct injection**: Used by settings preview (injects values directly)

---

## 8. Event Alarm Alerts

**File**: `ServicesCalendarService.swift` (within `checkForEventsToFire`)

### How They Work

Event alarm alerts are independent from config-based alerts. They fire based on the actual alarm/reminder dates set on calendar events (e.g., "Alert 15 minutes before" in Calendar.app).

### Alarm Date Extraction

From `CalendarEvent` construction:
- `EKAlarm.absoluteDate`: Used directly for absolute alarms
- `EKAlarm.relativeOffset`: Calculated as `eventStartDate + relativeOffset` (offset is negative, e.g., -900 for 15 min before)

### Firing Logic

```
if eventAlarmAlertsEnabled:
    for each event:
        if event.isAllDay AND NOT allDayEventAlertsEnabled: skip
        if event.id IN firedEventIDs: skip (user disabled this event)
        for each alarmDate in event.alarmDates:
            timeUntilAlarm = alarmDate - now
            dedupKey = "eventID_alarmTimestamp"

            if timeUntilAlarm <= 0 AND timeUntilAlarm > -120 seconds:
                if dedupKey NOT in alarmFiredIDs:
                    FIRE ALERT with eventAlarmAlertStyle
                    add dedupKey to alarmFiredIDs
```

Key points:
- **Per-alarm deduplication**: Uses `alarmFiredIDs` (separate from `alertFiredIDs` so each alarm fires regardless of config firings)
- **Multiple alarms per event**: Each alarm fires independently (e.g., 15-min and 5-min alarms both fire). `fireAlarmAlert` does NOT add the event to `firedEventIDs`, so normal alarm firing does not suppress subsequent alarms on the same event.
- **Dedup key format**: `"eventID_alarmTimestampAsTimeIntervalSinceReferenceDate"`
- **Style**: Configurable as `.mini` or `.fullScreen` via `eventAlarmAlertStyle` setting
- **Duration**: Configurable via `eventAlarmAlertDuration` (default 15 seconds, applies to mini style)

### Relationship with Config-Based Alerts

- Event alarm alerts use their own `alarmFiredIDs` tracking set for per-alarm dedup
- However, the per-event `firedEventIDs` guard IS consulted before processing a given event's alarm list. This means **"Disable alerts for this event" suppresses both config-based AND alarm-based alerts for that event.**
- If the user disables an event mid-alarm-sequence (e.g., after the 10-min alarm fires but before the 5-min alarm), subsequent alarms are also suppressed.
- Re-enabling the event via `reEnableEvent(eventID)` clears all tracking and allows both alert families to fire again.

---

## 9. Snooze System

**File**: `ServicesAlertCoordinator.swift`

### Full-Screen Snooze

1. User clicks snooze button and selects a duration (e.g., 5 minutes)
2. `AlertCoordinator` hides all alert windows immediately
3. Current alert item is removed from queue position 0
4. A `Timer` is scheduled for the snooze duration
5. When timer fires, the snoozed item is **appended to the end** of the queue (not inserted at position 0)
6. If no other alert is showing, the re-queued alert displays immediately
7. If another alert is showing, the snoozed alert waits its turn in queue

### Snooze Durations

- Configurable per alert config via `snoozeDurations` array
- Default: `[60, 300, 900]` (1 minute, 5 minutes, 15 minutes)
- Displayed as human-readable labels on the snooze dropdown

### Mini Banner Snooze

- Mini banners do not have snooze functionality
- They auto-dismiss or can be manually closed

---

## 10. Dismiss & Disable Behavior

### Dismiss (Full-Screen)

- **Escape key**: Dismisses current alert (handled by local/global event monitors)
- **X button**: Top-left circular dismiss button
- On dismiss: Alert removed from queue, next alert shown (if any)
- If queue empties: All alert windows hidden, app returns to `.accessory` activation policy

### Dismiss (Mini Banner)

- Banner auto-dismisses after configured duration
- No manual dismiss button (banner disappears on its own)

### Disable Alerts for Event

- Available on mini banners as a "Disable alerts" button, and via right-click context menu on upcoming events in the menu bar
- Adds the event ID to `firedEventIDs` in CalendarService
- Blocks ALL future config-based alerts for that event across all configs
- Also blocks ALL future event alarm alerts for that event (checked before iterating the event's `alarmDates` in `checkForEventsToFire()`)
- If applied mid-alarm-sequence (between two alarms on the same event), remaining alarms are suppressed
- Persisted to UserDefaults

### Re-Enable Alerts for Event

- `reEnableEvent(eventID)` removes the ID from:
  - `firedEventIDs`
  - All entries in `alertFiredIDs`
  - `alarmFiredIDs` entries matching that event
  - `preAlertEventIDs`
- Allows all alert types to fire again for that event

---

## 11. Sleep & Wake Handling

**File**: `ServicesCalendarService.swift`, `ServicesAppleRemindersService.swift`

### Sleep Detection (Gap-Based)

The 1-second fire check timer detects sleep by measuring elapsed time:

```
elapsed = now - lastCheckTime
if elapsed > 10 seconds:
    // System was asleep
    mark all past events as fired (silently, no alerts)
    update lastCheckTime
    return
```

This prevents a "storm" of alerts for events that occurred during sleep. Events that passed while the system was sleeping are silently suppressed.

### Wake Notification

On `NSWorkspace.didWakeNotification`:
- CalendarService re-fetches all events from EventKit
- AppleRemindersService re-fetches reminders
- The gap detection in the next fire check handles suppression

### System Clock Change

On `NSSystemClockDidChangeNotification`:
- Clears ALL tracking sets: `firedEventIDs`, `alertFiredIDs`, `alarmFiredIDs`, `preAlertEventIDs`
- Resets `AlertMergeBuffer`
- Re-fetches all upcoming events
- This handles timezone changes, manual clock adjustments, and DST transitions

### Calendar Database Change

On `EKEventStoreChanged`:
- Re-fetches upcoming events from EventKit
- Does NOT reset tracking sets (assumes minimal time has passed)

---

## 12. Custom Reminders

**File**: `ServicesReminderService.swift`, `CustomReminder.swift`

### Data Model

```swift
@Model final class CustomReminder {
    var id: UUID
    var title: String
    var scheduledDate: Date
    var hasFired: Bool
    var createdAt: Date
}
```

Persisted via SwiftData in `~/Library/Containers/com.zapcal/Data/Library/Application Support/`.

### Creating a Reminder

1. User clicks "Add ZapCal Reminder" in menu bar panel
2. `AddReminderView` opens as a standalone window (400x350)
3. User enters title and selects date/time
4. `ReminderService.addReminder()` saves to SwiftData
5. Reminder appears in menu bar event list (sorted by scheduled date)

### Firing Logic

- **Check timer**: Every **1 second**
- **No lead time**: Custom reminders fire at their exact scheduled time
- **Fire condition**: `timeUntilStart <= 0 AND timeUntilStart > -120 seconds`
- Uses the **first enabled AlertConfig** to determine display style
- Submitted to `AlertMergeBuffer` like calendar events

### Auto-Deletion

- After a full-screen alert fires for a custom reminder, the reminder is **automatically deleted** from SwiftData
- Mini alerts do NOT delete the reminder (it persists and may fire with the next config)
- Manual deletion available via "Manage Reminders" window

### Manage Reminders Window

- Lists all upcoming (unfired) custom reminders
- Edit and delete functionality
- Standalone window (not a sheet)

---

## 13. Apple Reminders Integration

**File**: `ServicesAppleRemindersService.swift`, `AppleReminder.swift`

### Data Model

```swift
struct AppleReminder {
    let id: String          // reminder.calendarItemIdentifier
    let title: String
    let dueDate: Date
    let reminderList: ReminderListInfo
    let notes: String?
}
```

### Fetching

- **Fetch window**: **2 weeks** ahead
- Only incomplete reminders with due dates
- Filtered to user-selected reminder lists
- Shared `EKEventStore` with CalendarService

### Firing Logic

- Fires **once** per reminder at due date
- **Fire condition**: `timeUntilDue <= 0 AND timeUntilDue > -120 seconds`
- Uses first enabled AlertConfig to determine style
- Sleep detection: Marks past reminders as fired silently (same 10-second gap detection)

### Enabling

- Controlled by `appleRemindersEnabled` setting (default: false)
- Requires Reminders permission (requested during onboarding)
- User selects which reminder lists to monitor

---

## 14. Alert Themes & Presets

### Full-Screen Theme (AlertTheme)

**File**: `AlertTheme.swift`

```swift
struct AlertTheme: Codable {
    var backgroundType: BackgroundType      // .solidColor or .image
    var solidColor: CodableColor
    var overlayColor: CodableColor
    var imageFileName: String?
    var elementStyles: [AlertElementIdentifier: AlertElementStyle]
}
```

**Customizable Elements** (AlertElementIdentifier):
- `.title` - Event title text
- `.startTime` - Time range text
- `.location` - Location text
- `.calendarName` - Calendar name text
- `.joinButton` - Join Meeting button
- `.snoozeButton` - Snooze button
- `.dismissButton` - Dismiss X button

**Per-Element Styling** (AlertElementStyle):
- Font: family, size, weight, color
- Text transforms: italic, uppercase, vertical scale, letter spacing
- Button-specific: background color
- Dismiss-specific: icon size, icon color

### Mini Alert Theme (PreAlertTheme)

**File**: `PreAlertTheme.swift`

```swift
struct PreAlertTheme: Codable {
    var backgroundType: BackgroundType
    var backgroundColor, overlayColor: CodableColor
    var titleColor, countdownColor: CodableColor
    var dismissButtonColor, dismissIconColor, progressRingColor: CodableColor
    var disableButtonTextColor, disableButtonBackgroundColor: CodableColor
    var joinButtonTextColor, joinButtonBackgroundColor: CodableColor
}
```

### Preset System

**Files**: `PresetManager.swift`, `PreAlertPresetManager.swift`

**Built-in full-screen presets** (bundled in app):
- Coral Paper FS, Pinka Blua FS, Hot Pink FS, Red on Pink FS, Bee Sting FS, Blue Ruin FS, Kinetic Orange FS, and others

**Built-in mini presets**:
- Coral Paper, Rose Cream, Teal Lavender, and others

**Custom presets**:
- Stored in app support directory
- Created via "Save as Preset" in Appearance settings
- Can override built-in presets (in DEBUG builds)

**Preset Loading**:
1. Load bundled presets from `Bundle.main`
2. Load custom presets from app support directory
3. Deduplicate by name (custom overrides built-in)
4. Sort with default preset first

### Preset Management

- **Copy**: Duplicates a preset with a new name
- **Rename**: Renames preset and updates all calendar assignments
- **Delete**: Removes preset and resets affected calendar assignments to default
- **Assign to Calendar**: Right-click context menu on preset
- **Assign to Reminder List**: Right-click context menu on preset

---

## 15. Theme Assignment to Calendars

**File**: `ThemeService.swift`

### Assignment Maps

```swift
var calendarPresetAssignments: [String: String]        // calendar ID -> full-screen preset name
var calendarPreAlertAssignments: [String: String]       // calendar ID -> mini preset name
```

### Resolution

```
getTheme(for calendarIdentifier):
    if calendarPresetAssignments[calendarID] exists:
        return that preset's theme
    else:
        return default preset theme ("Pinka Blua FS" for full-screen)

getPreAlertTheme(for calendarIdentifier):
    if calendarPreAlertAssignments[calendarID] exists:
        return that preset's theme
    else:
        return default preset theme ("Rose Cream" for mini)
```

### Persistence

- `preset_assignments.json` in app support directory
- `pre_alert_preset_assignments.json` in app support directory
- Updated whenever user assigns a preset to a calendar

### Cascading Updates

When a preset is renamed:
- All calendar assignments referencing the old name are updated to the new name

When a preset is deleted:
- All calendar assignments referencing that preset are removed (revert to default)

---

## 16. Alert Configurations

**File**: `AppSettings.swift`

### AlertConfig Structure

```swift
struct AlertConfig: Codable, Identifiable {
    var id: UUID
    var enabled: Bool
    var style: AlertStyle           // .mini or .fullScreen
    var leadTime: Double            // Seconds before event start
    var miniDuration: Double        // Seconds banner stays visible (0 = persist)
    var snoozeDurations: [Double]   // Seconds for each snooze option
}
```

### Default Configs

**Calendar alert configs** (`alertConfigs`) — two defaults on first launch:
1. **Mini alert**: enabled, `.mini` style, 60s lead time, 15s duration, snooze [60, 300, 900]
2. **Full-screen alert**: enabled, `.fullScreen` style, 0s lead time (fires at event start)

**Reminder alert configs** (`reminderAlertConfigs`) — one default on first launch:
1. **Full-screen alert**: enabled, `.fullScreen` style, 0s lead time (fires at due time)

Calendar events and reminders (both custom and Apple Reminders) use separate alert config arrays, allowing different timing and style settings for each.

### How Multiple Configs Work

- Each config fires independently for each event
- Example with calendar defaults: A meeting at 10:00 AM triggers:
  - Mini banner at 9:59 AM (60s before)
  - Full-screen alert at 10:00 AM (0s before)
- Each config has its own `alertFiredIDs` tracking set
- Configs can be enabled/disabled independently
- Users can add more configs or modify existing ones

---

## 17. Settings

**File**: `ViewsSettingsViewSettingsView.swift` and sub-views

### Settings Tabs (Sidebar Navigation)

1. **General** (`GeneralSettingsView.swift`):
   - Launch at login toggle
   - Enable alerts for all-day events toggle (default: off). When off, all-day events still appear in the menu bar but do not trigger any alerts (config-based or alarm-based). When on, all-day events are treated the same as timed events for alerting purposes.
   - Number of events in menu bar (1-99, default 50)
   - Event alarm alert settings: enable toggle, style picker, duration
   - Snooze button durations (3 configurable, in minutes)

2. **Alerts** (`AlertsSettingsView.swift`):
   - Segmented picker with **Calendar** and **Reminders** sub-tabs
   - Calendar sub-tab manages `alertConfigs` (for calendar events)
   - Reminders sub-tab manages `reminderAlertConfigs` (for custom and Apple Reminders)
   - Each sub-tab: list of AlertConfigs with enable/disable toggles
   - Each config shows summary: style, lead time, duration
   - Modal sheet for editing individual config details
   - Add/remove alert configs

3. **Calendars** (`CalendarsSettingsView.swift`):
   - Checkbox list of all available calendars
   - Grouped by calendar source (iCloud, Google, etc.)
   - Toggle which calendars trigger alerts

4. **Reminders** (when enabled):
   - Enable/disable Apple Reminders integration
   - Checkbox list of reminder lists to monitor

5. **Appearance** (`AppearanceSettingsView.swift`):
   - Full-screen theme editor
   - Per-calendar preset selection
   - Live preview of alert appearance
   - Element-level customization (click element to edit)
   - Background type selector (solid color / image)
   - Font controls, color pickers, text transforms

6. **Pre-Alert Presets** (`PreAlertPresetsView.swift`):
   - Mini alert theme editor
   - Preset selection and management
   - Live preview of mini banner

7. **Menu Bar Preset** (`MenuBarPresetView.swift`):
   - Choose which mini preset styles the menu bar event rows
   - Live preview

---

## 18. Welcome & Onboarding Flow

**File**: `ViewsWelcomeView.swift`

### Flow Steps

1. **Permissions Screen**:
   - Requests Calendar access (EventKit)
   - Requests Reminders access (EventKit)
   - Both permission buttons shown simultaneously
   - "Next" buttons trigger system permission dialogs (labeled "Next" rather than "Grant" so the flow reads as a wizard step — the system dialog itself handles the grant/deny wording)
   - "Skip" option available (shows menu bar info screen instead)

2. **"You're All Set" Screen**:
   - Confirmation with checkmark animation
   - Menu bar illustration showing where the ZapCal icon appears
   - Hand-drawn red arrow pointing to menu bar icon location

3. **Alert Preset Picker**:
   - Three options:
     - Single mini alert only
     - Single full-screen alert only
     - Dual alerts (mini first, then full-screen) - recommended
   - Selection creates the corresponding AlertConfig entries

4. **Menu Bar Info**:
   - Final screen explaining how to use the menu bar icon
   - Auto-opens the menu bar panel after completion
   - Menu bar icon pulses/wiggles for 5 seconds to draw attention

### Post-Onboarding

- `hasCompletedWelcomeSetup` flag set in UserDefaults
- Welcome screen never shown again unless reset
- App opens menu bar panel automatically on first run after setup

---

## 19. Pause / Resume

**File**: `AppSettings.swift`, checked in all services

### Behavior When Paused

- `AppSettings.shared.isPaused = true`
- **CalendarService**: Skips all alert firing in `checkForEventsToFire()`
- **ReminderService**: Skips all alert firing
- **AppleRemindersService**: Skips all alert firing
- **Menu bar icon**: Displays with a strikethrough overlay (visual indicator)
- **Events still fetch**: EventKit polling continues, menu bar list stays updated

### Toggle

- Right-click menu bar icon -> "Pause all ZapCal Alerts" / "Resume ZapCal Alerts"
- Persisted to UserDefaults (survives app restart)

---

## 20. Deduplication Strategies

### Calendar Event Deduplication

- **Key**: `eventIdentifier + "_" + startDate.timeIntervalSinceReferenceDate`
- **Purpose**: Handles recurring Google Calendar events that share the same `eventIdentifier` but have different start dates
- **Used during**: Event fetching (CalendarEvent construction)

### Config-Based Alert Deduplication

- **Tracking set**: `alertFiredIDs[configID: Set<String>]`
- **Key**: Event ID (the composite key from above)
- **Purpose**: Ensures each AlertConfig fires at most once per event
- **Scope**: Per-config (Config A firing doesn't prevent Config B from firing)

### Global Event Disable

- **Tracking set**: `firedEventIDs: Set<String>`
- **Key**: Event ID
- **Purpose**: Blocks ALL config-based alerts for an event (user action: "Disable alerts")
- **Persistence**: UserDefaults

### Alarm Alert Deduplication

- **Tracking set**: `alarmFiredIDs: Set<String>`
- **Key**: `"eventID_alarmTimestamp"` (alarm's timeIntervalSinceReferenceDate)
- **Purpose**: Allows multiple alarms per event to fire independently while preventing duplicates
- **Note**: Alarm firing itself does not add to `firedEventIDs`, so one alarm firing does not block the next. However, the outer loop does consult `firedEventIDs` so the user's "Disable alerts for this event" action blocks all remaining alarms for that event.

### Pre-Alert Deduplication

- **Tracking set**: `preAlertEventIDs` (in CalendarService)
- **Key**: Event ID or alarm-specific dedup key
- **Purpose**: Prevents the same mini banner from showing twice

### Merge Buffer Deduplication

- Pending items deduped by ID before flushing
- Prevents the same event from appearing twice in a merged alert

---

## 21. Persistence & Storage

### UserDefaults

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `launchAtLogin` | Bool | true | Launch app at system login |
| `numberOfEventsInMenuBar` | Int | 50 | Max events shown in menu bar |
| `isPaused` | Bool | false | Alert pause state |
| `calendarAlertsEnabled` | Bool | true | Enable calendar event alerts |
| `allDayEventAlertsEnabled` | Bool | false | Enable alerts for all-day events |
| `appleRemindersEnabled` | Bool | false | Enable Apple Reminders alerts |
| `eventAlarmAlertsEnabled` | Bool | true | Enable event alarm-based alerts |
| `eventAlarmAlertStyle` | AlertStyle | .mini | Style for alarm alerts |
| `eventAlarmAlertDuration` | Double | 15 | Duration for alarm mini banners |
| `snoozeDurations` | [Double] | [60, 300, 900] | Snooze options in seconds |
| `menuBarPresetName` | String | "Rose Cream" | Preset for menu bar styling |
| `alertConfigs` | JSON | (2 defaults) | Encoded AlertConfig array for calendar events |
| `reminderAlertConfigs` | JSON | (1 default) | Encoded AlertConfig array for reminders |
| `selectedCalendarIdentifiers` | JSON | [] | Enabled calendar IDs |
| `selectedReminderListIdentifiers` | JSON | [] | Enabled reminder list IDs |
| `firedEventIDs` | [String] | [] | Globally disabled event IDs |
| `hasCompletedWelcomeSetup` | Bool | false | Onboarding completion flag |

### App Support Directory

```
~/Library/Containers/com.zapcal/Data/Library/Application Support/ZapCal/
├── preset_assignments.json              # Calendar -> full-screen preset mapping
├── pre_alert_preset_assignments.json    # Calendar -> mini preset mapping
├── Presets/                             # Full-screen theme presets
│   ├── Coral_Paper_FS.json
│   ├── Pinka_Blua_FS.json
│   └── [custom presets].json
└── PreAlertPresets/                     # Mini alert theme presets
    ├── Coral_Paper.json
    ├── Rose_Cream.json
    └── [custom presets].json
```

### SwiftData

```
~/Library/Containers/com.zapcal/Data/Library/Application Support/
└── default.store                        # CustomReminder model container
```

---

## 22. Memory & Performance

### Panel & Window Reuse

- Menu bar panel reused across open/close cycles (not recreated)
- Full-screen alert windows reused across alerts (rootView updated, not reallocated)
- Settings window reused (heavy views torn down on hide)
- Prevents SwiftUI's ~10-20 MB/cycle memory leak from window recreation

### Image Processing

- Background images loaded asynchronously on background thread
- Blur + downscaling applied off-main-thread (Core Image)
- Prevents UI freezes during image processing
- Images deallocated when alert windows are hidden

### Event Monitors

- Global/local event monitors created once and reused
- Not created/destroyed per panel open/close cycle

### Memory Leak Prevention

- `NSZombieEnabled` disabled (was causing observed memory leaks)
- Weak references in closures and timer callbacks
- Deinit implementations on NSHostingView subclasses to release GPU textures
- Baseline memory: ~50 MB (down from 300+ MB after optimization)

### Font Pre-Warming

- System font list pre-loaded at app launch on background thread
- Prevents slow first-open of Presets tab (system font enumeration is expensive)

---

## 23. Video Conference URL Detection

**File**: `CalendarEvent.swift`

### Detection Sources (checked in order)

1. **Structured data**: `EKEvent.url` property
2. **Location field**: Parsed for URL patterns
3. **Notes field**: Scanned for URL patterns
4. **Location string**: Regex match for video URLs

### Recognized Services

| Service | URL Patterns |
|---------|-------------|
| Zoom | `zoom.us/j/`, `zoom.us/my/` |
| Google Meet | `meet.google.com/` |
| Microsoft Teams | `teams.microsoft.com/` |
| Webex | `webex.com/` |
| GoToMeeting | `gotomeeting.com/` |

### URL Unwrapping

- Google redirect URLs (`google.com/url?q=...`) are unwrapped to extract the actual meeting URL
- The Join Meeting button displays the service name (e.g., "Join Zoom Meeting")

### Display Behavior

- Video conference URLs are hidden from the location display
- Join Meeting button appears only when a VC URL is detected
- Button opens URL in default browser

---

## 24. Migration Logic

### SubtleToMiniMigration (v1.0.8)

**File**: `SubtleToMiniMigration.swift`

Converts all "subtle" terminology to "mini" throughout persisted data:

1. **UserDefaults**: Renames keys containing "subtle" to "mini"
2. **AlertConfigs JSON**: Updates style values from "subtle" to "mini"
3. **On-disk preset files**: Renames files and updates internal references
4. **One-time execution**: Tracked by `hasRunSubtleToMiniMigration` flag

### Old Theme Migration (ThemeService)

Converts legacy per-calendar theme storage to the preset-based system:

1. Reads old `themes.json` file (per-calendar AlertTheme objects)
2. Creates individual preset files for each theme
3. Creates preset assignment entries
4. Archives old `themes.json` as backup
5. One-time execution on first launch after migration

---

## 25. Free Trial & In-App Purchase

**Files**: `ServicesTrialManager.swift`, `ServicesStoreManager.swift`

### Trial System

- **Duration**: 7-day free trial from first launch
- **Start date source**: In production, uses App Store receipt `originalPurchaseDate` (tamper-proof). Falls back to local UserDefaults date if receipt unavailable. In DEBUG builds, uses local UserDefaults date for testing.
- **Remaining days**: Calculated at midnight boundaries using `Calendar.dateComponents`

### Trial States

| State | Description |
|-------|-------------|
| `loading` | Initial state while checking receipt/purchase status |
| `active(daysRemaining)` | Trial active, shows days remaining in menu bar panel |
| `expired` | Trial ended, app locked to purchase screen |
| `purchased` | Full version unlocked via IAP |

### Trial Active Behavior

While the trial is active (`.active(daysRemaining)`):
- A banner at the top of the menu bar panel displays "X days remaining in your free trial"
- The banner includes a **"Purchase"** button (compact, no price shown) that invokes the same purchase flow as the expired view
- Rest of the menu bar UI (event list, settings gear, right-click actions) remains fully available
- Alerts fire normally

### Trial Expired Behavior

When the trial expires:
- Menu bar panel shows `trialExpiredView` instead of the event list
- Shows app icon, "Free Trial Expired" message, a prominent **"Purchase — {displayPrice}"** button (full-width, shows localized price), and a "Restore Purchase" option
- Settings gear button is hidden
- Right-click menu shows only "Free Trial Expired" (disabled) and "Quit"
- Alerts stop firing

### In-App Purchase

- **Product ID**: `spotlessmindsoftware.ZapCal.fullversion`
- **Framework**: StoreKit 2

### Purchase Flow

1. User taps purchase button in the trial expired view
2. Menu bar panel dismisses
3. App activation policy changes to `.regular` (required for StoreKit sheet)
4. 200ms delay for cleanup
5. `product.purchase()` shows Apple's system purchase sheet
6. On success: transaction verified, finished, `isPurchased = true`, TrialManager refreshed
7. App returns to `.accessory` activation policy
8. Shows "Thank You!" confirmation screen in the menu bar panel
9. Purchase status monitored continuously via `Transaction.updates` listener

### Purchase Restoration

- `AppStore.sync()` syncs with the App Store
- Re-checks entitlements for product ID match
- TrialManager state refreshed to `.purchased` if valid

### Purchase State Persistence

- Purchase status checked on every launch via `Transaction.currentEntitlement(for:)`
- Persists across app restarts without additional UserDefaults storage

### TestFlight Bypass

- **Detection**: Uses StoreKit 2 `AppTransaction.shared` to check `transaction.environment == .sandbox` (guarded by `#if !DEBUG`)
- **Behavior**: TestFlight builds (sandbox environment) skip trial evaluation entirely and set `trialState = .purchased`
- **Debug builds**: Unaffected — Xcode debug builds go through the normal trial/purchase flow so the full IAP experience can be tested locally via the StoreKit configuration file
- **Production builds**: Unaffected — App Store builds (production environment) use the real trial and purchase logic
- **Why not receipt URL or provisioning profile?**: On macOS, TestFlight builds use `receipt` (not `sandboxReceipt`) as the receipt filename, and Apple strips `embedded.provisionprofile` from TestFlight builds. `AppTransaction.environment` is the only reliable detection method on macOS.

---

## 26. About ZapCal Screen

**File**: `ViewsAboutView.swift`

### Screen Content

- **App icon**: 128x128 pixels, from `NSApp.applicationIconImage`
- **App name**: "ZapCal" in 24pt bold
- **Version**: "Version X.Y.Z (buildNumber)" in 12pt secondary color
- **Company**: "by Spotless Mind Software" in 14pt medium weight
- **Contact**: "Feedback & Questions:" label with clickable mailto link to `spotlessmindsoftware@gmail.com`

### Access

- **Menu bar panel**: "About ZapCal" button above "Quit" in the panel footer
- **Right-click menu**: "About ZapCal" menu item above "Quit"
- Opens as a standalone window (320px wide, titled, closable)
- Window is reused across open/close cycles (same pattern as other managed windows)
- Dock icon shown while About window is open, hidden when closed

---

## 27. File & Code Organization

### Services (Stateful Singletons)

| Service | Responsibility |
|---------|---------------|
| `CalendarService` | Event fetching, alert fire checking, deduplication |
| `ReminderService` | Custom reminder CRUD and fire checking |
| `AppleRemindersService` | Apple Reminders fetching and fire checking |
| `AlertCoordinator` | Full-screen alert window management and queue |
| `PreAlertManager` | Mini banner window management |
| `AlertMergeBuffer` | Coalesces simultaneous alerts |
| `ThemeService` | Calendar-to-preset assignment mapping |
| `PresetManager` | Full-screen preset loading and persistence |
| `PreAlertPresetManager` | Mini preset loading and persistence |
| `StoreManager` | In-app purchase management (StoreKit 2) |
| `TrialManager` | 7-day free trial tracking and state |
| `AlertCheckCoordinator` | Minute-boundary synchronized alert check scheduling |

### Models

| Model | Description |
|-------|-------------|
| `CalendarEvent` | Wraps EKEvent with dedup ID and extracted metadata |
| `CustomReminder` | SwiftData model for in-app reminders |
| `AppleReminder` | Wraps EKReminder with extracted metadata |
| `AlertTheme` | Full-screen alert visual configuration |
| `PreAlertTheme` | Mini alert visual configuration |
| `AlertConfig` | Alert trigger configuration (style, timing, snooze) |
| `AlertItem` | Queued alert item (single or merged) |

### View Hierarchy

```
Full_Screen_Calendar_ReminderApp
├── AppDelegate (menu bar, window management)
├── MenuBarView (event list, actions)
├── FullScreenAlertView (alert content)
├── PreAlertBannerView (mini banner content)
├── SettingsView
│   ├── GeneralSettingsView
│   ├── AlertsSettingsView
│   ├── CalendarsSettingsView
│   ├── AppearanceSettingsView
│   ├── PreAlertPresetsView
│   └── MenuBarPresetView
├── WelcomeView (onboarding flow)
├── ManageRemindersView (reminder list)
├── AddReminderView (reminder creation form)
└── AboutView (app info, company, contact)
```
