# ZapCal Alert Trigger Test Plan

A comprehensive, human-readable test plan for ZapCal's alert system. Each test lists preconditions, steps, and the expected outcome. Tests are grouped by scenario category.

## Vocabulary

- **Config-based alert** — an alert fired because of an entry in `AppSettings.alertConfigs` (the "Alerts" settings tab). Each config has its own style (mini / full-screen), `leadTime`, `miniDuration`, and `snoozeDurations`.
- **Event alarm alert** — an alert fired because a calendar event carries an `EKAlarm` (e.g., Google Calendar "15 minutes before" notification). These are independent of config-based alerts and obey `eventAlarmAlertsEnabled` / `eventAlarmAlertStyle`.
- **Mini alert / pre-alert** — banner panel (top-right, 460×108) with a countdown. Auto-dismisses after `miniDuration` (0 = persist until event starts).
- **Full-screen alert** — overlay window covering every screen at `.screenSaver` level. Queued; one shown at a time. Supports snooze.
- **Merged alert** — a single alert that represents 2+ events that all fire inside the same minute boundary. If any merged item is full-screen, the merged alert is full-screen.
- **Disable for event** — adds the event to `firedEventIDs`; blocks future config-based alerts for that event but not alarm alerts.
- **Fire window** — an alert fires when `timeUntilStart <= leadTime && timeUntilStart > -120` (2-minute grace period past start).

## Default Baseline

Unless noted, tests assume the default configuration:
- Two config-based calendar alerts: Mini @ 60s lead, 15s duration + Full-screen @ 0s lead.
- One reminder config: Full-screen @ 0s lead.
- `allDayEventAlertsEnabled = false`
- `eventAlarmAlertsEnabled = true`, style `.mini`, duration 15s
- `appleRemindersEnabled = false`
- `isPaused = false`
- Not on TestFlight, not in trial-expired state.
- Exactly one calendar selected.

Every test should be run from a clean state: re-enable any disabled events, resume if paused, and clear pending snoozes.

---

## 1. Single-Event Baseline Firing

### 1.1 Mini banner fires at lead time
**Preconditions:** Default configs. Calendar event scheduled for 2 minutes from now.
**Steps:** Wait for the minute boundary 1 minute before start.
**Expected:** Mini banner appears top-right, shows event title, "Starts in 1:00" countdown. Banner auto-dismisses after 15s (or sooner if event starts).

### 1.2 Full-screen fires at start time
**Preconditions:** Default configs. Event scheduled for 2 minutes from now.
**Steps:** Wait until the event's start minute boundary.
**Expected:** Mini banner (from 1.1) is gone. A full-screen overlay covers every display with the selected preset theme. Queue indicator not shown (queue size = 1).

### 1.3 Single-event with custom lead time
**Preconditions:** Edit mini config to `leadTime = 300` (5 minutes). Event scheduled for 6 minutes from now.
**Steps:** Wait 1 minute.
**Expected:** Mini banner fires at T−5:00.

### 1.4 Mini duration = 0 persists until event start
**Preconditions:** Mini config `leadTime = 600`, `miniDuration = 0`. Event scheduled for 11 minutes from now.
**Steps:** Wait for T−10:00, then observe banner without interaction.
**Expected:** Banner remains visible, countdown updates every second, banner disappears only when event start time is reached (or full-screen alert replaces it).

### 1.5 Grace period for slightly-past events
**Preconditions:** Full-screen config `leadTime = 0`. Manually create event with start = 90 seconds ago.
**Steps:** Wait for next minute boundary.
**Expected:** Full-screen alert still fires (within 120s grace window). Event at T+121s or later is silently suppressed.

### 1.6 Outside fire window, no alert
**Preconditions:** Default configs. Event scheduled 2 hours from now.
**Steps:** Observe for one minute boundary.
**Expected:** No alert. Event still appears in menu bar list.

---

## 2. Multiple Configs On One Event

### 2.1 Mini + Full-screen on same event (default)
**Preconditions:** Default 2 configs. Event in 2 minutes.
**Steps:** Observe through start.
**Expected:** Mini fires at T−1:00, full-screen fires at T+0:00. Both tracked independently in `alertFiredIDs`.

### 2.2 Three configs on same event
**Preconditions:** Add third config: Full-screen @ 300s lead. Event in 6 minutes.
**Steps:** Observe.
**Expected:** Full-screen fires at T−5:00, mini at T−1:00, full-screen again at T+0:00. Each fires exactly once.

### 2.3 Disabled config is skipped
**Preconditions:** Mini config `enabled = false`. Event in 2 minutes.
**Steps:** Observe.
**Expected:** Only the full-screen alert fires at T=0. No mini banner.

### 2.4 Re-firing prevention for same config
**Preconditions:** Mini config lead = 60s, event in 90 seconds.
**Steps:** Wait for mini to fire. Dismiss. Wait another minute.
**Expected:** Mini does not re-fire. Full-screen fires at T=0 and does not trigger a duplicate mini.

---

## 3. Multiple Events Firing Simultaneously (Merge)

### 3.1 Two events at the same minute — mini merge
**Preconditions:** Disable the full-screen config so only the mini config remains. Two events start at the same minute, 2 minutes from now.
**Steps:** Wait for T−1:00 minute boundary.
**Expected:** One merged mini banner titled with both event titles (bulleted). Panel height expands to accommodate both rows. Countdown shows earliest start.

### 3.2 Three events merged
**Preconditions:** Three events at the same start minute, default configs.
**Steps:** Wait for T=0 boundary.
**Expected:** One merged full-screen alert listing all three titles as bullets.

### 3.3 Four+ events merged — "and X more" overflow
**Preconditions:** Four events at the same start minute.
**Steps:** Wait for T=0.
**Expected:** Merged alert shows first 3 titles plus "and 1 more". No separate alert windows for overflow items.

### 3.4 Style escalation — any full-screen → all full-screen
**Preconditions:** Event A: full-screen-only config at 0s. Event B: mini-only config at 0s. Both start the same minute.
**Steps:** Wait.
**Expected:** A single merged full-screen alert appears (because any full-screen in the batch escalates the whole merge). No separate mini banner.

### 3.5 Events at different configs within same minute
**Preconditions:** Default configs. Event A starts in 2 min, Event B starts in 1 min. At the T−1:00 boundary for A, Event B is firing its full-screen.
**Steps:** Wait.
**Expected:** Single merged alert appears. Style escalates to full-screen because B's full-screen is in the batch. A's title still appears.

### 3.6 Same minute but different services
**Preconditions:** One calendar event at T=0, one custom reminder at T=0, one Apple reminder at T=0 (enable Apple reminders). All full-screen.
**Steps:** Wait for T=0.
**Expected:** All three merge into one full-screen alert (`AlertCheckCoordinator` collects across services before flushing merge buffer).

### 3.7 Near-simultaneous but crossing minute boundary
**Preconditions:** Event A starts at 10:00:15, Event B starts at 10:00:45. Both have `leadTime = 0`.
**Steps:** Observe.
**Expected:** Both fire at the same 10:00 minute tick and are merged (the second is computed inside `timeUntilStart <= 0` at the same `tick()`).

### 3.8 Non-overlapping minute boundaries — no merge
**Preconditions:** Event A at 10:00, Event B at 10:01.
**Steps:** Observe.
**Expected:** Two separate alerts, queued. Queue indicator "1 of 2" / "2 of 2".

---

## 4. Full-Screen Queue Behavior

### 4.1 Queue indicator appears when 2+ queued
**Preconditions:** Two events with full-screen alerts start 30s apart within the same minute (and therefore merge). Counter example: 3.8.
**Expected:** For 3.8 scenario, "1 of 2" shown on first alert. After dismissing, "1 of 1" (or hidden) on second.

### 4.2 Queue order follows start date
**Preconditions:** Create two events starting at 10:00 and 10:01. At 9:59 force both full-screen configs to fire by shrinking lead time to 60s.
**Steps:** Wait for 9:59 boundary.
**Expected:** Alerts merged? (Check — both fire at 9:59 boundary: A has lead 60s, B has lead 120s → yes, same tick, merged.) Adjust: make A lead=60, B lead=0. Then A fires at 9:59, B at 10:01 separately, B queued if A still visible.

### 4.3 Dismiss with Escape advances queue
**Preconditions:** Queue with two alerts.
**Steps:** Press Esc on first.
**Expected:** First dismissed, second appears immediately with updated queue indicator.

### 4.4 Dismiss with X button advances queue
**Same as 4.3 but click the close button.**
**Expected:** Same behavior.

### 4.5 Only one alert visible at a time
**Preconditions:** Queue of 3.
**Steps:** Observe windows via Mission Control.
**Expected:** Exactly one full-screen alert visible per display. The other two are queued, not layered.

---

## 5. Snooze Scenarios

### 5.1 Basic snooze for default duration
**Preconditions:** Single full-screen alert visible. `snoozeDurations = [60, 300, 900]`.
**Steps:** Click snooze, select 1 minute.
**Expected:** Alert window hides immediately. 1 minute later the same alert reappears (or is queued behind any newer pending items).

### 5.2 Snooze appends to end of queue (not front)
**Preconditions:** Three full-screen alerts in queue (A visible, B and C queued).
**Steps:** Snooze A for 1 minute. Wait 1 minute.
**Expected:** B appears immediately after snoozing A. Then C after B. When A's snooze expires, A is appended to queue and shown after C is dismissed. Sequence: A → B → C → A (not A → A → B → C).

### 5.3 Snooze when queue is empty
**Preconditions:** Only one alert visible, queue empty.
**Steps:** Snooze 5 minutes. Wait 5 minutes without new alerts.
**Expected:** Alert reappears immediately when timer fires.

### 5.4 Per-config snooze durations override global
**Preconditions:** Config A snoozeDurations = [120]. Global `AppSettings.snoozeDurations = [60, 300, 900]`. Event fires from Config A.
**Steps:** Open snooze dropdown.
**Expected:** Dropdown shows only "2 minutes" (config value), not global.

### 5.5 Mini banner has no snooze
**Preconditions:** Mini banner active.
**Steps:** Inspect banner UI.
**Expected:** No snooze control visible. Only auto-dismiss and "Disable alerts for this event" are available.

### 5.6 Multiple overlapping snoozes
**Preconditions:** Alert A snoozed 1m, Alert B snoozed 2m, fresh Alert C arrives at 30s.
**Steps:** Observe over 3 minutes.
**Expected:** C shows immediately. A returns at T+1m (queued behind whatever is visible). B returns at T+2m.

### 5.7 Snooze across event start time
**Preconditions:** Event starts in 1 minute. Mini already fired and snooze selected (not valid — mini has no snooze). Use full-screen fired early due to lead time. Snooze 5m.
**Steps:** Observe until event actually starts, then another 5 minutes.
**Expected:** Snoozed alert still reappears 5 minutes later. Being past the event start does not cancel the snooze timer.

### 5.8 Snooze persists only in memory
**Preconditions:** Alert snoozed 5m. Quit app immediately.
**Steps:** Relaunch app.
**Expected:** Snoozed alert is lost (not rescheduled after relaunch). Tracking sets remain so alert does not re-fire from original trigger. Known limitation — document observed behavior.

---

## 6. Dismiss / Disable / Re-enable

### 6.1 Disable alerts from mini banner
**Preconditions:** Mini banner visible for event.
**Steps:** Click "Disable alerts for this event".
**Expected:** Banner disappears. Full-screen alert does NOT fire at T=0. Event still appears in menu bar list with a visual marker indicating disabled state.

### 6.2 Disable from right-click in menu bar panel
**Preconditions:** Upcoming event in menu bar list.
**Steps:** Right-click event → "Disable alerts for this event".
**Expected:** No alerts of any config-based type will fire for this event.

### 6.3 Disabled event still shows alarm alerts
**Preconditions:** Event with an `EKAlarm` set (e.g., 10 minutes before). Event disabled via 6.2. `eventAlarmAlertsEnabled = true`.
**Steps:** Wait until T−10:00.
**Expected:** Event alarm alert STILL fires (disable only affects config-based alerts). Document this behavior.

### 6.4 Re-enable clears all tracking
**Preconditions:** Event previously disabled; alert already fired on a different config; alarm already fired.
**Steps:** Right-click → "Re-enable alerts for this event".
**Expected:** Event removed from `firedEventIDs`, from every `alertFiredIDs[configID]`, and from `alarmFiredIDs`. If still within fire window for any config, alerts may re-fire on next tick.

### 6.5 Disabling persists across restarts
**Preconditions:** Event disabled.
**Steps:** Quit and relaunch app.
**Expected:** Event remains disabled (UserDefaults `firedEventIDs`). No alerts fire.

### 6.6 Escape dismisses full-screen without disabling
**Preconditions:** Full-screen visible.
**Steps:** Press Esc.
**Expected:** Alert dismissed. Event NOT added to `firedEventIDs`. If another config for this event has not yet fired, it will still fire.

### 6.7 X button dismisses full-screen without disabling
**Same as 6.6 via button.**

---

## 7. Event Alarm Alerts (Independent Path)

### 7.1 Single alarm fires
**Preconditions:** Event with one `EKAlarm` (−15 min). `eventAlarmAlertsEnabled = true`, style `.mini`.
**Steps:** Wait until T−15:00 boundary.
**Expected:** Mini banner (style configured by `eventAlarmAlertStyle`) fires. Dedup key `eventID_timestamp`.

### 7.2 Multiple alarms on one event
**Preconditions:** Event with three alarms (−30, −15, −5).
**Steps:** Observe.
**Expected:** Three separate alarm alerts fire at each timestamp. Each tracked separately in `alarmFiredIDs`.

### 7.3 Alarm + config-based alerts on same event
**Preconditions:** Default configs + event with −10 min alarm. Event in 15 minutes.
**Steps:** Observe through start.
**Expected:** Alarm alert at T−10, mini config at T−1, full-screen config at T=0. Three alerts total.

### 7.4 Alarm alerts disabled globally
**Preconditions:** `eventAlarmAlertsEnabled = false`. Event with alarm.
**Steps:** Wait until alarm time.
**Expected:** No alarm alert. Config-based alerts still fire normally.

### 7.5 Alarm alert style toggle
**Preconditions:** `eventAlarmAlertStyle = .fullScreen`. Event with alarm.
**Steps:** Wait until alarm time.
**Expected:** Full-screen alert fires from alarm path (not mini). Duration uses `eventAlarmAlertDuration`.

### 7.6 Absolute alarm vs relative alarm
**Preconditions:** Two events — one with absolute alarm (`absoluteDate = 10:00`), one with relative (−15 min from 10:15).
**Steps:** Both should fire at 10:00.
**Expected:** Both fire; both dedup keys preserved.

### 7.7 Alarm does not fire twice for same timestamp
**Preconditions:** Alarm fires at T=10:00. User dismisses. Next `tick()` runs at 10:01.
**Expected:** No re-fire (present in `alarmFiredIDs`).

### 7.8 Re-enable event also clears alarm tracking
Covered by 6.4.

---

## 8. Recurring Events

### 8.1 Each occurrence fires independently
**Preconditions:** Daily recurring event at 10:00.
**Steps:** Observe across two days.
**Expected:** Alerts fire both days. Dedup key includes the start date, so day 2 is a different key from day 1.

### 8.2 Disabling one occurrence does not affect others
**Preconditions:** Daily recurring event. Disable alerts for today's occurrence via right-click.
**Steps:** Observe today and tomorrow.
**Expected:** Today: no alerts. Tomorrow: normal alerts fire (different composite key).

### 8.3 Google-calendar recurring with multiple results
**Preconditions:** Google recurring meeting that appears as multiple EventKit entries.
**Steps:** Observe one day's occurrence.
**Expected:** Only one set of alerts fires (deduped on `eventIdentifier + startDate`).

### 8.4 Series alarm on recurring event
**Preconditions:** Recurring event with −10 min alarm.
**Steps:** Observe two occurrences.
**Expected:** Alarm alerts fire for both (different dedup keys).

---

## 9. All-Day Events

### 9.1 All-day events ignored by default
**Preconditions:** `allDayEventAlertsEnabled = false`. All-day event today.
**Steps:** Wait until midnight or observe at app launch.
**Expected:** No alerts (config-based OR alarm-based). Event still appears in menu bar list.

### 9.2 All-day events with setting enabled
**Preconditions:** `allDayEventAlertsEnabled = true`. All-day event tomorrow.
**Steps:** Observe around midnight transition.
**Expected:** Config-based alerts fire using the all-day event's start (midnight). Alarms respected if present.

---

## 10. Back-to-Back, Overlapping, and Contiguous Events

### 10.1 Back-to-back meetings
**Preconditions:** Event A 10:00–11:00, Event B 11:00–12:00. Default configs.
**Steps:** Observe around 11:00.
**Expected:** At 10:59 → mini for B. At 11:00 → full-screen for B (and A does not produce a full-screen since its start already fired earlier).

### 10.2 Overlapping meetings
**Preconditions:** Event A 10:00–11:00, Event B 10:30–11:30.
**Steps:** Observe 10:29 and 10:30.
**Expected:** Mini for B at 10:29 (if A's full-screen has been dismissed). Full-screen for B at 10:30. Both alert independently — no conflict detection.

### 10.3 Three meetings starting within 60 seconds
**Preconditions:** Events at 10:00:00, 10:00:20, 10:00:50.
**Steps:** Observe.
**Expected:** One merged full-screen alert at 10:00 tick containing all three.

### 10.4 Meetings one minute apart — no merge
**Preconditions:** Events at 10:00 and 10:01.
**Steps:** Observe both minute boundaries.
**Expected:** Two separate alerts queued. Alert at 10:01 is queued behind 10:00's alert if still visible.

---

## 11. Event Lifecycle

### 11.1 Event deleted before fire window
**Preconditions:** Event scheduled for 2 hours from now.
**Steps:** Delete in Calendar.app.
**Expected:** Within 30s (next fetch) the event disappears from menu bar. No alert ever fires.

### 11.2 Event deleted while mini banner visible
**Preconditions:** Mini banner showing for event.
**Steps:** Delete event in Calendar.app.
**Expected:** Banner remains until duration expires (current behavior — document). Full-screen at T=0 does NOT fire because event has been removed from fetched set.

### 11.3 Event rescheduled earlier into fire window
**Preconditions:** Event was 2 hours away; reschedule to 2 minutes from now.
**Steps:** Observe after EventKit change notification.
**Expected:** On next tick after fetch, alerts begin firing according to new timing.

### 11.4 Event rescheduled later out of fire window
**Preconditions:** Event was in 2 minutes; reschedule to 2 hours.
**Steps:** Observe.
**Expected:** Any already-fired alerts stay fired (but the event's presence in `alertFiredIDs` uses the new start? — verify). No new alerts fire until within new fire window. If new start reaches fire window later, alerts fire again only if dedup key differs (it does, because it includes startDate).

### 11.5 Declined event
**Preconditions:** Meeting where you have declined participation.
**Steps:** Observe.
**Expected:** Event not present in menu bar, no alerts ever fire.

### 11.6 Invited event you haven't responded to
**Preconditions:** Needs-action participation status.
**Steps:** Observe.
**Expected:** Alerts fire normally. Document in test result.

### 11.7 Stale fired-ID pruning
**Preconditions:** Event fired 3 days ago and is now in the past.
**Steps:** Observe UserDefaults `firedEventIDs` and `alertFiredIDs` after a fetch cycle.
**Expected:** Stale IDs pruned when no longer returned by EventKit query window.

---

## 12. Custom Reminders (ZapCal Reminders)

### 12.1 Basic custom reminder
**Preconditions:** Create reminder via "Add ZapCal Reminder" at T+2m. Default `reminderAlertConfigs` (full-screen at 0s lead).
**Steps:** Wait.
**Expected:** Full-screen alert at T=0.

### 12.2 Auto-delete after full-screen fire
**Preconditions:** Custom reminder fires full-screen and user dismisses.
**Steps:** Open "Manage Reminders".
**Expected:** Reminder removed from SwiftData store.

### 12.3 Mini alert does not auto-delete
**Preconditions:** `reminderAlertConfigs` set to mini. Reminder fires.
**Steps:** Open "Manage Reminders" after dismissal.
**Expected:** Reminder still present in list.

### 12.4 Reminder merge with calendar event
**Preconditions:** Custom reminder and calendar event both at T=0, both full-screen.
**Steps:** Wait.
**Expected:** Single merged full-screen alert listing both.

### 12.5 Edit reminder scheduled date
**Preconditions:** Existing reminder at 10:00. Edit to 10:30.
**Steps:** Observe both times.
**Expected:** Fires only at 10:30.

### 12.6 Delete reminder manually
**Preconditions:** Reminder scheduled for T+5m. Delete via Manage Reminders.
**Steps:** Wait.
**Expected:** No alert.

---

## 13. Apple Reminders Integration

### 13.1 Apple reminders disabled (default)
**Preconditions:** `appleRemindersEnabled = false`. Apple reminder due in 2 minutes.
**Steps:** Wait.
**Expected:** No ZapCal alert. Apple's own system notification may fire (not ZapCal's concern).

### 13.2 Apple reminders enabled, list selected
**Preconditions:** `appleRemindersEnabled = true`, one list selected. Reminder due in 2 minutes.
**Steps:** Wait.
**Expected:** ZapCal full-screen fires at due time (0s lead default).

### 13.3 Apple reminder 2-week fetch window
**Preconditions:** Reminder due in 3 weeks.
**Steps:** Observe menu bar list.
**Expected:** Reminder not shown (outside 2-week window). Will be picked up in a later fetch when within window.

### 13.4 Completed reminder
**Preconditions:** Apple reminder marked completed.
**Steps:** Observe.
**Expected:** Never appears in menu bar, never fires alerts.

### 13.5 Reminder with no due date
**Preconditions:** Incomplete reminder with no due date.
**Steps:** Observe.
**Expected:** Ignored.

---

## 14. Pause / Resume

### 14.1 Pause prevents all alerts
**Preconditions:** `isPaused = true` via right-click menu. Event in 2 minutes.
**Steps:** Wait.
**Expected:** No mini, no full-screen, no alarm alert. Event still in menu bar. Menu bar icon reflects paused state.

### 14.2 Resume during fire window
**Preconditions:** Paused. Event at T−30s (inside 60s mini lead).
**Steps:** Resume via right-click.
**Expected:** On next tick, mini banner fires (event still within lead window).

### 14.3 Resume after event passed
**Preconditions:** Paused. Event start time passed by 5 minutes.
**Steps:** Resume.
**Expected:** No alert (outside grace window).

### 14.4 Pause while alert is visible
**Preconditions:** Full-screen alert visible.
**Steps:** Pause via right-click.
**Expected:** Existing alert stays up until dismissed (or remains? — document observed behavior). Future events suppressed.

---

## 15. Sleep / Wake / Lock / Terminate

### 15.1 Silent catch-up on wake
**Preconditions:** Event scheduled for 20 minutes from now. Sleep Mac. Wake 30 minutes later.
**Steps:** Observe on wake.
**Expected:** No alert for the missed event (gap detection suppresses). Future events still alert normally.

### 15.2 Wake within fire window
**Preconditions:** Event in 2 minutes. Sleep Mac immediately. Wake 30s later.
**Steps:** Observe.
**Expected:** Gap < 120s — not treated as sleep. Alerts fire normally.

### 15.3 Lock screen does not suppress alert
**Preconditions:** Event in 2 minutes. Lock screen (not sleep).
**Steps:** Wait.
**Expected:** Full-screen alert window appears at `.screenSaver` level, visible over lock screen. Unlocking shows the alert.

### 15.4 App terminated, event passed
**Preconditions:** Quit ZapCal. Event at +5 minutes passes. Relaunch ZapCal.
**Steps:** Observe on relaunch.
**Expected:** Gap detection (or simply not firing for past events) — no retroactive alert. Verify menu bar shows current upcoming events.

### 15.5 System clock change (manual)
**Preconditions:** Event fired and is in `firedEventIDs`. Manually change system clock backward by 1 hour.
**Steps:** Observe after clock change.
**Expected:** All tracking sets cleared. Events re-fetched. Alerts may fire again for events now "in the future".

### 15.6 DST transition
**Preconditions:** Event scheduled during a DST spring-forward or fall-back hour.
**Steps:** Observe at the transition.
**Expected:** System clock-change handler clears tracking; alerts fire once for the absolute time EventKit reports.

### 15.7 Time zone change (travel)
**Preconditions:** Change Mac timezone.
**Steps:** Observe after change.
**Expected:** Tracking cleared; events re-fetched using new timezone; alerts fire at correct local time.

### 15.8 Screensaver active
**Preconditions:** Screensaver running. Event at T=0.
**Steps:** Wait.
**Expected:** Full-screen alert appears above screensaver.

---

## 16. Multi-Monitor Behavior

### 16.1 Alert on all displays
**Preconditions:** Two external monitors attached. Full-screen alert fires.
**Expected:** One alert window on each display. Primary shows full content; secondaries show title + time only.

### 16.2 Monitor hot-plug while alert visible
**Preconditions:** Alert visible. Attach or detach a monitor.
**Expected:** Windows reconciled: new monitor gets a window, removed monitor cleans up.

### 16.3 Single monitor baseline
**Preconditions:** One display. Alert fires.
**Expected:** One window with full content.

### 16.4 Mini banner placement with multiple monitors
**Preconditions:** Multi-monitor. Mini fires.
**Expected:** Banner shows on primary screen only, top-right, below menu bar.

---

## 17. Trial & TestFlight Gating

### 17.1 Active trial — alerts fire
**Preconditions:** Trial state `active(daysRemaining: 5)`. Event in 2 minutes.
**Steps:** Observe.
**Expected:** Alerts fire normally.

### 17.2 Expired trial — no alerts
**Preconditions:** Trial state `expired`. Event in 2 minutes.
**Steps:** Observe.
**Expected:** No alerts. Menu bar shows "Free Trial Expired" view. Settings gear hidden.

### 17.3 Purchased — alerts fire
**Preconditions:** Trial state `purchased`.
**Steps:** Observe event firing.
**Expected:** Alerts fire normally, no trial UI.

### 17.4 TestFlight build — always purchased
**Preconditions:** TestFlight distribution.
**Steps:** Launch and observe.
**Expected:** `AppTransaction.environment == .sandbox` detected, trial bypassed, state = purchased. Alerts fire normally.

### 17.5 Trial expires while alert visible
**Preconditions:** Trial has 1 minute left, full-screen alert visible.
**Steps:** Wait until expiry.
**Expected:** Existing alert not forcibly hidden (document observed behavior). New alerts suppressed.

### 17.6 Purchase during expired state
**Preconditions:** Trial expired, user purchases via IAP.
**Steps:** Complete purchase. Observe event firing 2 minutes later.
**Expected:** After TrialManager refresh, alerts resume.

### 17.7 Restore purchases
**Preconditions:** Trial expired, previously purchased on another Mac with same Apple ID.
**Steps:** Tap restore.
**Expected:** Entitlement restored, alerts resume.

---

## 18. Settings Interactions

### 18.1 Changing lead time mid-session
**Preconditions:** Event in 5 minutes. Mini config lead = 60s.
**Steps:** Change lead to 300s.
**Expected:** Mini fires at next tick (since `timeUntilStart <= 300`).

### 18.2 Disabling config mid-session
**Preconditions:** Event in 2 minutes.
**Steps:** Disable mini config.
**Expected:** Mini does not fire. Full-screen still fires.

### 18.3 Adding new config mid-session
**Preconditions:** Event in 10 minutes. Add third config: full-screen @ 300s lead.
**Steps:** Wait 5 minutes.
**Expected:** Third config fires at T−5:00.

### 18.4 Deleting a config mid-session
**Preconditions:** Three configs, all have fired for an event earlier.
**Steps:** Delete one config.
**Expected:** `alertFiredIDs[deletedConfigID]` orphaned (harmless). Event firing continues from remaining configs.

### 18.5 Calendar deselected mid-session
**Preconditions:** Calendar A selected, event in 2 minutes on Calendar A.
**Steps:** Deselect Calendar A.
**Expected:** Event removed from fetched set; no alerts fire.

### 18.6 New calendar selected mid-session
**Preconditions:** Calendar B had unselected event in 2 minutes. Select Calendar B.
**Steps:** Wait.
**Expected:** Event appears in next fetch; alerts fire normally.

### 18.7 Changing theme mid-session
**Preconditions:** Alert visible with theme X.
**Steps:** Switch theme in settings.
**Expected:** Currently visible alert keeps X (no hot-reload). Next alert uses new theme.

### 18.8 Per-calendar preset assignment
**Preconditions:** Calendar A → Preset X, Calendar B → Preset Y.
**Steps:** Fire events from both.
**Expected:** Each uses its assigned preset.

### 18.9 Delete assigned preset
**Preconditions:** Calendar A assigned to custom preset "Foo". Delete "Foo".
**Steps:** Fire event from Calendar A.
**Expected:** Falls back to default ("Pinka Blua FS" for full-screen / "Rose Cream" for mini).

---

## 19. Video Conference Join Button

### 19.1 Zoom URL in event URL field
**Preconditions:** Event with `https://zoom.us/j/123` in URL field.
**Expected:** Full-screen alert shows "Join Meeting" button that opens the URL.

### 19.2 Google Meet in location field
**Preconditions:** Event with `https://meet.google.com/abc-defg-hij` in location field.
**Expected:** "Join Meeting" button visible. Location display hides the URL.

### 19.3 Teams link in notes
**Preconditions:** Event with Teams link only in notes/description.
**Expected:** "Join Meeting" button visible.

### 19.4 No video URL
**Preconditions:** In-person meeting, no URL anywhere.
**Expected:** No "Join Meeting" button shown.

### 19.5 FaceTime link
**Preconditions:** Event with `https://facetime.apple.com/join#...`.
**Expected:** Join button opens FaceTime app.

### 19.6 Click Join does not dismiss alert
**Preconditions:** Full-screen alert visible with Join button.
**Steps:** Click Join.
**Expected:** Browser/app opens. Alert remains visible until user dismisses.

---

## 20. Additional Edge Cases

### 20.1 Event with very long title
**Preconditions:** Event title > 200 characters.
**Expected:** Title truncates gracefully in both mini and full-screen alerts. No layout break.

### 20.2 Event with emoji in title
**Preconditions:** Title contains emoji.
**Expected:** Rendered correctly in both alert styles.

### 20.3 Event in the past at app launch
**Preconditions:** Launch ZapCal with an event that started 30 minutes ago (and has end time in future).
**Expected:** No retroactive alert. Event still shown in menu bar (ongoing).

### 20.4 Event starting at exact launch moment
**Preconditions:** Launch ZapCal at 10:00:00 for an event starting 10:00:00.
**Expected:** First tick happens on next minute boundary (10:01:00). Alert fires on that tick because event is within grace window.

### 20.5 Very short events (1-minute duration)
**Preconditions:** Event 10:00–10:01.
**Expected:** Full-screen fires at 10:00. No separate alert for end.

### 20.6 Event starting same second as snooze reappearance
**Preconditions:** Alert A snoozed 60s. Event B starting 60s from now.
**Steps:** Observe T+60s.
**Expected:** Both fire at the same tick; merged if both full-screen; else A queued behind B.

### 20.7 Hundreds of events in fetch window
**Preconditions:** 200+ events in next 2 weeks.
**Expected:** No alert performance degradation. Menu bar list respects `numberOfEventsInMenuBar` cap (default 50).

### 20.8 Calendar permission revoked mid-session
**Preconditions:** Grant permission initially. Revoke via System Settings.
**Steps:** Wait for next fetch.
**Expected:** Graceful failure — no crash, no alerts, menu bar shows permission prompt.

### 20.9 Reminders permission revoked
**Same as 20.8 for Reminders.**
**Expected:** Apple reminders stop firing, no crash.

### 20.10 Disk full / SwiftData write failure
**Preconditions:** Simulate disk full while creating custom reminder.
**Expected:** Error surfaced in UI, not silent data loss.

---

## 21. Regression Matrix Quick Checklist

A 10-minute sanity pass before every release:

- [ ] 1.1 Mini fires 1 minute before
- [ ] 1.2 Full-screen fires at start
- [ ] 3.2 Three merged events show as one alert with bullets
- [ ] 5.1 Snooze 1-minute returns alert after 1 minute
- [ ] 5.2 Snooze appends to end of queue (not front)
- [ ] 6.1 Disable from mini suppresses full-screen
- [ ] 6.4 Re-enable re-fires alerts
- [ ] 7.3 Alarm + config alerts all fire for same event
- [ ] 8.1 Recurring event fires both days
- [ ] 9.1 All-day events skip alerts by default
- [ ] 11.1 Deleted event disappears and does not alert
- [ ] 14.1 Pause suppresses all alerts
- [ ] 15.1 Wake from sleep does not storm alerts
- [ ] 16.1 Full-screen alert shows on every connected monitor
- [ ] 17.2 Expired trial blocks all alerts
- [ ] 19.1 Join Meeting button opens Zoom URL

---

## How to Execute a Test

1. Set the preconditions exactly as written (check AppSettings, trial state, selected calendars).
2. Create the event(s) in the system Calendar (or Reminders) app that the test needs. Use absolute times close to "now + 2 minutes" so waits are short.
3. Observe without interacting until the expected tick, then perform any required interactions (dismiss, snooze, disable).
4. Record PASS / FAIL along with a note on any deviation (e.g., banner appeared 3 seconds late, queue indicator missing).
5. Reset state between tests: re-enable any disabled events, resume if paused, delete test events, clear custom reminders, restore default configs.

A helper: `reset-app.sh` at the project root wipes local state and is useful between large test batches.
