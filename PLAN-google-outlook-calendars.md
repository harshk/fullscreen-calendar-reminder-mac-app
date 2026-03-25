# Implementation Plan: Direct Google Calendar & Outlook Integration

## Goal

Allow users to connect Google Calendar and Outlook accounts directly from within the app, without configuring them in macOS System Settings → Internet Accounts. These cloud calendars run alongside the existing EventKit-based local/iCloud calendars.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                     CalendarService                          │
│  (orchestrator — merges events from all sources)             │
│                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│   │  EventKit     │  │  Google       │  │  Outlook          │ │
│   │  Provider     │  │  Provider     │  │  Provider         │ │
│   │  (existing)   │  │  (new)        │  │  (new)            │ │
│   └──────────────┘  └──────────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

`CalendarService` becomes an orchestrator that merges events from multiple **calendar providers**. Each provider conforms to a shared protocol and handles its own auth, fetching, and calendar listing.

---

## Part 1: Calendar Provider Protocol

Create a protocol that all calendar sources conform to. This lets CalendarService treat EventKit, Google, and Outlook uniformly.

### New file: `CalendarProvider.swift`

```swift
/// A unified calendar descriptor (not tied to EventKit)
struct CalendarInfo: Identifiable, Hashable {
    let id: String              // unique across all providers
    let title: String
    let color: Color
    let accountName: String     // e.g. "iCloud", "user@gmail.com"
    let providerType: ProviderType

    enum ProviderType: String, Codable {
        case eventKit, google, outlook
    }
}

/// Protocol for all calendar event sources
protocol CalendarProvider {
    var providerType: CalendarInfo.ProviderType { get }
    var isAuthenticated: Bool { get }
    var calendars: [CalendarInfo] { get }

    func fetchEvents(
        from startDate: Date,
        to endDate: Date,
        calendars: [CalendarInfo]
    ) async throws -> [CalendarEvent]

    func loadCalendars() async throws
}
```

### Impact on `CalendarEvent`

`CalendarEvent` currently depends on `EKEvent` and `EKParticipantStatus`. It already has a mock initializer that doesn't require EventKit types — the Google/Outlook providers would use that pattern. The `EventCalendarInfo` inner struct maps cleanly to the new `CalendarInfo`.

One change: `participationStatus` is currently `EKParticipantStatus` (an EventKit enum). Replace with an app-owned enum:

```swift
enum ParticipationStatus: String, Codable {
    case accepted, declined, tentative, pending, unknown
}
```

Map `EKParticipantStatus` → `ParticipationStatus` in the EventKit provider, and map Google/Outlook API responses to the same enum.

---

## Part 2: EventKit Provider (refactor existing code)

Extract the existing EventKit logic from `CalendarService` into its own provider.

### New file: `EventKitProvider.swift`

Move from `CalendarService`:
- `EKEventStore` instance
- `requestAccess()`, `hasAccess`, `checkAuthorizationStatus()`
- `loadCalendars()` — returns `[CalendarInfo]` instead of `[EKCalendar]`
- `fetchUpcomingEvents()` logic — accepts date range + selected calendars, returns `[CalendarEvent]`

`CalendarService` keeps: polling timers, alert firing logic, event merging, system notifications. It calls into `EventKitProvider` (and later Google/Outlook providers) for data.

---

## Part 3: Account Manager

A persistent store for connected cloud accounts.

### New file: `CloudAccountManager.swift`

```swift
struct CloudAccount: Codable, Identifiable {
    let id: String              // UUID
    let type: CalendarInfo.ProviderType  // .google or .outlook
    let email: String
    let addedDate: Date
}

class CloudAccountManager: ObservableObject {
    static let shared = CloudAccountManager()
    @Published private(set) var accounts: [CloudAccount] = []

    // Persistence: JSON file in App Support (like preset_assignments.json)
    // Token storage: macOS Keychain (access token + refresh token per account)

    func addAccount(_ account: CloudAccount)
    func removeAccount(_ id: String)    // also revokes token + clears Keychain
    func accessToken(for accountID: String) async throws -> String  // refreshes if expired
}
```

**Token storage**: Use `Security.framework` (Keychain) directly, or the `KeychainAccess` SPM package for convenience. Store per account:
- Access token (short-lived, ~1 hour)
- Refresh token (long-lived)
- Token expiry date

**Token refresh**: When `accessToken(for:)` is called and the token is expired, automatically POST to the provider's token endpoint with the refresh token. If the refresh token is also invalid (revoked), mark the account as needing re-authentication and surface this in the UI.

---

## Part 4: Google Calendar Integration

### 4a. OAuth Setup

**Prerequisites**: Register an app in [Google Cloud Console](https://console.cloud.google.com):
1. Create a project
2. Enable "Google Calendar API"
3. Create OAuth 2.0 credentials (type: macOS / Desktop application)
4. Note the **Client ID** (desktop apps don't use a client secret for PKCE flows)

**OAuth flow** using `ASWebAuthenticationSession`:

```
1. Generate a random code_verifier + code_challenge (PKCE)
2. Open ASWebAuthenticationSession to:
   https://accounts.google.com/o/oauth2/v2/auth
     ?client_id=YOUR_CLIENT_ID
     &redirect_uri=com.yourapp:/oauth2callback  (custom URL scheme)
     &response_type=code
     &scope=https://www.googleapis.com/auth/calendar.readonly
     &code_challenge=...
     &code_challenge_method=S256
3. User signs in, grants permission
4. App receives authorization code via redirect
5. Exchange code for tokens:
   POST https://oauth2.googleapis.com/token
     grant_type=authorization_code
     code=AUTH_CODE
     client_id=YOUR_CLIENT_ID
     code_verifier=...
     redirect_uri=...
6. Store access_token, refresh_token, expires_in in Keychain
```

**Custom URL scheme**: Register `com.yourapp` (or similar) in Info.plist under `CFBundleURLSchemes` so the OAuth redirect comes back to your app.

### 4b. Google Calendar API Client

### New file: `GoogleCalendarProvider.swift`

**List calendars**:
```
GET https://www.googleapis.com/calendar/v3/users/me/calendarList
Authorization: Bearer ACCESS_TOKEN
```
Response includes `id`, `summary` (title), `backgroundColor` for each calendar.

**Fetch events**:
```
GET https://www.googleapis.com/calendar/v3/calendars/{calendarId}/events
  ?timeMin=2026-03-18T00:00:00Z
  &timeMax=2026-04-01T00:00:00Z
  &singleEvents=true          (expands recurring events)
  &orderBy=startTime
Authorization: Bearer ACCESS_TOKEN
```

**Incremental sync** (optional optimization):
- First request returns a `nextSyncToken`
- Subsequent requests send `syncToken` param → API returns only changed/deleted events
- Reduces data transfer from full re-fetch every 30s to tiny delta responses
- Falls back to full fetch if sync token expires (410 Gone response)

**Mapping to `CalendarEvent`**:
| Google API field | CalendarEvent field |
|---|---|
| `id` + `start.dateTime` | `id` (prefixed with `google_` to avoid collisions) |
| `summary` | `title` |
| `start.dateTime` | `startDate` |
| `end.dateTime` | `endDate` |
| `location` | `location` |
| `description` | `notes` |
| `start.date` (no time) | `isAllDay = true` |
| `attendees[].self=true` → `responseStatus` | `participationStatus` |
| `hangoutLink` or `conferenceData.entryPoints[].uri` | `videoConferenceURL` |

---

## Part 5: Outlook / Microsoft 365 Integration

### 5a. OAuth Setup

**Prerequisites**: Register an app in [Azure Portal → App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps):
1. New registration → "Accounts in any organizational directory and personal Microsoft accounts"
2. Redirect URI: type "Public client/native (mobile & desktop)", value `com.yourapp://auth`
3. API Permissions → add `Calendars.Read` (delegated)
4. Note the **Application (client) ID**

**OAuth flow** — nearly identical to Google, also uses PKCE:

```
1. Generate code_verifier + code_challenge
2. Open ASWebAuthenticationSession to:
   https://login.microsoftonline.com/common/oauth2/v2.0/authorize
     ?client_id=YOUR_CLIENT_ID
     &redirect_uri=com.yourapp://auth
     &response_type=code
     &scope=Calendars.Read offline_access
     &code_challenge=...
     &code_challenge_method=S256
3. User signs in, grants permission
4. Exchange code for tokens:
   POST https://login.microsoftonline.com/common/oauth2/v2.0/token
     grant_type=authorization_code
     client_id=YOUR_CLIENT_ID
     code=AUTH_CODE
     code_verifier=...
     redirect_uri=...
5. Store access_token, refresh_token in Keychain
```

Note: `offline_access` scope is required to get a refresh token.

### 5b. Microsoft Graph API Client

### New file: `OutlookCalendarProvider.swift`

**List calendars**:
```
GET https://graph.microsoft.com/v1.0/me/calendars
Authorization: Bearer ACCESS_TOKEN
```
Response includes `id`, `name`, `hexColor` for each calendar.

**Fetch events**:
```
GET https://graph.microsoft.com/v1.0/me/calendars/{id}/calendarView
  ?startDateTime=2026-03-18T00:00:00Z
  &endDateTime=2026-04-01T00:00:00Z
  &$orderby=start/dateTime
  &$top=100
Authorization: Bearer ACCESS_TOKEN
```
`calendarView` automatically expands recurring events (like Google's `singleEvents=true`).

**Incremental sync** (optional optimization):
- Use delta queries: `GET /me/calendarView/delta?startDateTime=...&endDateTime=...`
- Returns a `@odata.deltaLink` for subsequent requests
- Similar concept to Google's syncToken

**Mapping to `CalendarEvent`**:
| Graph API field | CalendarEvent field |
|---|---|
| `id` + `start.dateTime` | `id` (prefixed with `outlook_`) |
| `subject` | `title` |
| `start.dateTime` | `startDate` (parse with timezone from `start.timeZone`) |
| `end.dateTime` | `endDate` |
| `location.displayName` | `location` |
| `bodyPreview` | `notes` |
| `isAllDay` | `isAllDay` |
| `attendees[].status.response` where `emailAddress` matches account | `participationStatus` |
| `onlineMeeting.joinUrl` | `videoConferenceURL` |

---

## Part 6: Refactored CalendarService

`CalendarService` becomes a coordinator that:

1. Holds an array of `CalendarProvider` instances (EventKit + one per cloud account)
2. On each 30s poll, calls `fetchEvents()` on all providers in parallel (`TaskGroup`)
3. Merges results into a single `upcomingEvents` array
4. Deduplicates (a user might have the same event in EventKit AND a direct Google connection)
5. The existing 1-second fire-check timer, alert triggering, and everything downstream is unchanged

### Deduplication strategy

If a user has the same Google account in both System Settings (EventKit) and the direct connection, events will appear twice. Deduplicate by:
- Matching on `title` + `startDate` (within 1-minute tolerance) + `calendar title`
- Prefer the EventKit version (since it integrates with the OS)
- Or: warn the user in Settings that a calendar appears in both sources

### Updated `availableCalendars`

Currently `[EKCalendar]`. Change to `[CalendarInfo]` — the unified struct from the protocol. The Calendars settings tab groups by `accountName` instead of `EKSource.title`.

### Updated `selectedCalendarIdentifiers`

Currently stores EventKit calendar identifiers. The `CalendarInfo.id` should be prefixed by provider type (e.g. `eventkit_XXXX`, `google_XXXX`, `outlook_XXXX`) to ensure uniqueness across providers. Existing saved identifiers need a one-time migration to add the `eventkit_` prefix.

---

## Part 7: UI Changes

### Calendars Settings Tab (`CalendarsSettingsView`)

Add an "Accounts" section above the calendar list:

```
┌─────────────────────────────────────────────┐
│  Connected Accounts                         │
│                                             │
│  ● iCloud (via System Settings)             │
│  ● user@gmail.com          [Disconnect]     │
│  ● user@outlook.com        [Disconnect]     │
│                                             │
│  [+ Add Google Account]  [+ Add Outlook]    │
├─────────────────────────────────────────────┤
│  Calendars                                  │
│                                             │
│  ▸ iCloud                                   │
│    ☑ Personal    Preset: [Coral Paper FS]   │
│    ☑ Work        Preset: [Blue Ruin FS]     │
│  ▸ user@gmail.com                           │
│    ☑ Team Cal    Preset: [Kinetic Orange]   │
│  ▸ user@outlook.com                         │
│    ☑ Meetings    Preset: [Pinka Blua]       │
└─────────────────────────────────────────────┘
```

The "Add Google Account" / "Add Outlook" buttons trigger the OAuth flow via `ASWebAuthenticationSession`.

### Error states to handle in UI

- Token expired / revoked → show "Re-authenticate" button next to the account
- API quota exceeded → show warning, fall back to less frequent polling
- Network offline → show subtle indicator, keep showing cached events

---

## Part 8: New Files Summary

| File | Purpose |
|---|---|
| `CalendarProvider.swift` | Protocol + `CalendarInfo` struct + `ParticipationStatus` enum |
| `EventKitProvider.swift` | Extracted EventKit logic from CalendarService |
| `GoogleCalendarProvider.swift` | Google OAuth + Calendar API client |
| `OutlookCalendarProvider.swift` | Microsoft OAuth + Graph API client |
| `CloudAccountManager.swift` | Persists connected accounts, manages Keychain tokens |
| `OAuthService.swift` | Shared PKCE helpers, `ASWebAuthenticationSession` wrapper, token refresh |

### Modified files

| File | Changes |
|---|---|
| `CalendarService.swift` | Becomes orchestrator; delegates to providers; merges events |
| `CalendarEvent.swift` | Replace `EKParticipantStatus` with app-owned enum; keep mock init |
| `CalendarsSettingsView.swift` | Add accounts section; change `EKCalendar` → `CalendarInfo` |
| `AppSettings.swift` | Migrate `selectedCalendarIdentifiers` to prefixed format |
| `Info.plist` | Add custom URL scheme for OAuth redirects |
| `*.entitlements` | Add `com.apple.security.network.client` (outgoing connections) |

---

## Part 9: Dependencies

**None required.** Everything can be done with system frameworks:
- `AuthenticationServices` → `ASWebAuthenticationSession` for OAuth
- `Security` → Keychain for token storage
- `Foundation` → `URLSession` for API calls

Optional SPM packages that reduce boilerplate:
- `KeychainAccess` — simpler Keychain API (but Security.framework works fine)
- No Google/Microsoft SDKs needed — raw REST + PKCE is simpler for this use case

---

## Part 10: Implementation Order

### Phase 1 — Refactor (no new functionality)
1. Create `CalendarProvider` protocol and `CalendarInfo` struct
2. Create `ParticipationStatus` enum, update `CalendarEvent`
3. Extract `EventKitProvider` from `CalendarService`
4. Update `CalendarService` to use the provider protocol
5. Update `CalendarsSettingsView` to use `CalendarInfo` instead of `EKCalendar`
6. Verify everything works exactly as before

### Phase 2 — OAuth & Account Infrastructure
7. Create `OAuthService` (PKCE helpers, ASWebAuthenticationSession wrapper)
8. Create `CloudAccountManager` (account persistence, Keychain token storage)
9. Register custom URL scheme in Info.plist
10. Add network entitlement

### Phase 3 — Google Calendar
11. Register app in Google Cloud Console
12. Implement `GoogleCalendarProvider` (OAuth flow + API client)
13. Add "Add Google Account" to CalendarsSettingsView
14. Wire into CalendarService polling
15. Test end-to-end: sign in → calendars appear → events show → alerts fire

### Phase 4 — Outlook Calendar
16. Register app in Azure Portal
17. Implement `OutlookCalendarProvider` (OAuth flow + API client)
18. Add "Add Outlook Account" to CalendarsSettingsView
19. Wire into CalendarService polling
20. Test end-to-end

### Phase 5 — Polish
21. Deduplication logic for overlapping EventKit + direct connections
22. Error handling UI (expired tokens, network errors)
23. Incremental sync optimization (syncToken / deltaLink)
24. Migration of existing `selectedCalendarIdentifiers` to prefixed format

---

## Security Considerations

- **Client IDs** will be embedded in the app binary. This is standard for desktop OAuth apps — the PKCE flow ensures security without a client secret.
- **Tokens in Keychain**: Use `kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked` so tokens aren't accessible when the Mac is locked.
- **Scope minimization**: Request only `calendar.readonly` / `Calendars.Read` — never write access.
- **Token revocation**: When a user disconnects an account, revoke the token with the provider's revocation endpoint before deleting from Keychain.
- **No server component**: All auth is device-local. No backend needed.

---

## App Store / Notarization Notes

- Google and Microsoft both allow desktop OAuth apps without App Review for calendar read-only access.
- Google requires a "consent screen" configuration and may require verification if the app will have >100 users. Until verified, users see an "unverified app" warning during sign-in.
- Microsoft requires admin consent for organizational accounts in some tenants; personal accounts work immediately.
- The `com.apple.security.network.client` entitlement is required for outgoing HTTPS connections and is compatible with App Sandbox / notarization.
