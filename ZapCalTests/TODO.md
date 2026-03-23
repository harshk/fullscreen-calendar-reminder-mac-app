# Implementation TODO List

## Critical Path Items ✅

These are all implemented:

- [x] Models
  - [x] AlertTheme with full codable support
  - [x] CalendarEvent wrapper
  - [x] CustomReminder SwiftData model
  - [x] AppSettings with @Published properties

- [x] Services
  - [x] CalendarService with EventKit integration
  - [x] ThemeService for persistence
  - [x] AlertCoordinator for queue management
  - [x] ReminderService for CRUD

- [x] Views
  - [x] FullScreenAlertView with theme support
  - [x] MenuBarView with event list
  - [x] AddReminderView with validation
  - [x] ManageRemindersView with edit/delete
  - [x] SettingsView with tabs
  - [x] GeneralSettingsView
  - [x] CalendarsSettingsView
  - [x] AppearanceSettingsView (theme editor)

- [x] App Infrastructure
  - [x] AppDelegate with status bar
  - [x] Main app file with SwiftData
  - [x] Unit tests
  - [x] Documentation

## Nice-to-Have Improvements 🎨

### UI Polish
- [ ] Add loading states when fetching calendars
- [ ] Add animation when alert appears
- [ ] Smoother transitions between queued alerts
- [ ] Better empty states with illustrations
- [ ] Keyboard navigation in settings

### Theme Editor Enhancements
- [ ] Drag-and-drop element positioning on preview
- [ ] Snap-to-grid guidelines
- [ ] Undo/redo for theme changes
- [ ] Color presets/palettes
- [ ] Font previews in picker

### Error Handling
- [ ] Better error messages for calendar access
- [ ] Retry mechanism for EventKit failures
- [ ] User-facing error alerts
- [ ] Crash reporting/analytics

### Performance
- [ ] Cache calendar colors
- [ ] Optimize theme encoding/decoding
- [ ] Lazy load calendar events
- [ ] Debounce theme property changes

### Accessibility
- [ ] VoiceOver labels for all controls
- [ ] Keyboard shortcuts for alert dismissal
- [ ] High contrast mode support
- [ ] Reduce motion support

### Testing
- [ ] Add UI tests for critical paths
- [ ] Integration tests for calendar service
- [ ] Performance tests for large event lists
- [ ] Test with 100+ calendars
- [ ] Multi-monitor configuration tests

## Known Issues / Future Work 🔧

### Current Limitations
1. **Drag-and-drop element positioning**: Currently uses sliders, not true drag-and-drop
   - Would require custom gesture handlers on preview
   - Complex hit testing in scaled preview

2. **Font picker**: Currently a text field, not a proper font picker
   - Could use NSFontManager for better UX
   - Preview fonts in dropdown

3. **Image aspect ratio**: Always uses aspect-fit
   - Could add aspect-fill option
   - Position control for images

4. **Pause icon**: Uses bell.slash but could be more obvious
   - Consider colored indicator
   - Animation on toggle

5. **Video conference detection**: Pattern-based, not perfect
   - EventKit structured data support varies by service
   - May miss some URLs

### Edge Cases to Test
- [ ] 50+ simultaneous events (queue stress test)
- [ ] Very long event titles (text wrapping)
- [ ] Events without titles
- [ ] Calendars with special characters in names
- [ ] Time zone changes
- [ ] Daylight saving time transitions
- [ ] Multiple accounts with same calendar name
- [ ] Rapid calendar database changes
- [ ] Low disk space scenarios
- [ ] Multiple displays with different resolutions

## Documentation Improvements 📝

- [ ] Add inline code documentation
- [ ] Create video walkthrough
- [ ] Screenshots for README
- [ ] API documentation with DocC
- [ ] Contributing guidelines
- [ ] Changelog format

## Distribution Prep 📦

### Code Signing
- [ ] Configure automatic signing
- [ ] Create distribution profile
- [ ] Set up notarization
- [ ] Test sandboxed environment thoroughly

### App Store Metadata
- [ ] App description
- [ ] Keywords
- [ ] Screenshots (multiple sizes)
- [ ] App preview video
- [ ] Privacy policy
- [ ] Support URL

### Marketing
- [ ] Landing page
- [ ] Social media assets
- [ ] Press kit
- [ ] Demo video

## Post-Launch Features 🚀

These align with PRD "Future Considerations":

### High Priority
- [ ] Advance alert timing (5, 15, 30 min before)
- [ ] Sound alerts with customizable sounds
- [ ] Snooze button (5, 10, 15 min options)

### Medium Priority
- [ ] Multiple named themes per calendar
- [ ] Theme import/export as .fscr files
- [ ] Global keyboard shortcut to pause/unpause
- [ ] Menu bar badge with event count

### Low Priority
- [ ] macOS widget with upcoming events
- [ ] Siri integration for custom reminders
- [ ] iCloud sync for themes and custom reminders
- [ ] Calendar-specific pause
- [ ] Focus mode integration

## Refactoring Opportunities 🔨

### Code Quality
- [ ] Extract common SwiftUI view modifiers
- [ ] Create reusable components library
- [ ] Consolidate color/font utilities
- [ ] Abstract UserDefaults access
- [ ] Protocol-based service abstraction for testing

### Architecture
- [ ] Consider MVVM for complex views
- [ ] Dependency injection for services
- [ ] Repository pattern for data access
- [ ] Command pattern for undo/redo

### Performance
- [ ] Profile with Instruments
- [ ] Optimize theme preview rendering
- [ ] Reduce memory footprint
- [ ] Background queue for heavy operations

## Security & Privacy 🔒

- [ ] Audit data collection (currently zero)
- [ ] Review entitlements (minimal necessary)
- [ ] Validate all user inputs
- [ ] Secure storage for sensitive data
- [ ] Regular dependency updates

## Localization 🌍

- [ ] Extract all strings to Localizable.strings
- [ ] Support right-to-left languages
- [ ] Date/time formatting per locale
- [ ] Number formatting per locale
- [ ] Test with multiple languages

## Analytics (Optional) 📊

If you decide to add analytics:
- [ ] Feature usage tracking
- [ ] Error tracking
- [ ] Performance metrics
- [ ] A/B testing infrastructure
- [ ] Privacy-first implementation

## Community

- [ ] GitHub issues template
- [ ] Pull request template
- [ ] Code of conduct
- [ ] License file (choose one)
- [ ] Contributor recognition

---

## Priority Matrix

**Must Have (Blocking v1.0 launch):**
- Everything in "Critical Path Items" ✅ (DONE!)

**Should Have (Polish for v1.0):**
- Better error handling
- Accessibility improvements
- More comprehensive tests

**Could Have (v1.1):**
- Drag-and-drop theme editing
- Sound alerts
- Snooze functionality

**Won't Have (v2.0+):**
- iCloud sync
- Siri integration
- Advanced analytics

---

## Current Status: ✅ FEATURE COMPLETE

All v1.0 requirements from the PRD are implemented. The app is ready for:
1. Testing
2. Bug fixing
3. Polish
4. Deployment

Next recommended steps:
1. Build and run the app
2. Test all features against acceptance criteria
3. Fix any bugs discovered
4. Polish UI/UX based on user feedback
5. Prepare for distribution
