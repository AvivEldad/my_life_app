# Notification review

## Confirmed bugs corrected

- Motivational notifications were regenerated on each launch/edit, including slots
  that had already fired that day. Randomizing them again could produce more than
  two deliveries. Times are now persisted by calendar date; refreshes are serialized
  and notification IDs remain stable as the 30-day window rolls forward.
- Existing schedules are migrated by cancelling legacy IDs and skipping the rest
  of the migration day, since the old version did not store delivery history.
- Android's missing `ActionBroadcastReceiver` prevented notification action buttons
  from reaching the background handler. The manifest now registers it.
- Snoozing used to replace the recurring habit reminder with a single alarm, losing
  subsequent reminders. Snoozes now have separate IDs alongside future occurrences.
- Scheduling daily/weekly habits using only a time/weekday could remind about an
  occurrence completed early. The installed Android plugin (17.2.4) recalculates
  repeating alarms from the current date, ignoring the supplied start date. Habits
  now use explicit one-shot occurrence dates, refreshed at startup/resume.
- Habit IDs no longer depend on Dart's implementation-defined string hash. They use
  a stable hash and reserved ID blocks; legacy schedules are cancelled by payload.
- Notification settings assumed there was a golden task and passed a fake due-task
  count. Settings now refresh from actual open tasks. Task saves, batch saves and
  deletions also refresh golden/weekly reminders so completed tasks stop reminding.
- Weekly reminders repeated a stale days-left message indefinitely. They now use
  dated one-shot alarms through the task's actual deadline.
- Strike/due-date repeating messages could claim yesterday's state was today's.
  These now prompt the user to check current status without stale counts.
- Calendar-day arithmetic replaces 24-hour additions in notification planning and
  habit recurrence. Monthly habits retain their configured day after shorter months.
- The weekly selection reminder existed but had no caller; it is now scheduled
  during home-page startup/resume checks.

## Remaining limitations and review findings

- This is an Android notification implementation. iOS/macOS initialization and
  action registration are absent; this change does not add other platform support.
- Schedules are finite: motivational notifications cover 30 days; habits cover 30
  daily, 8 weekly, or 6 monthly occurrences. Opening/resuming the home page refills
  them. No background worker refills schedules while the app stays unopened.
  Large numbers of habits can also hit device alarm limits.
- Habit miss processing still runs when the habits page first loads. Its deadline
  equals the reminder time (plus snoozes), so opening that page just after a reminder
  can apply a miss penalty immediately. Defining a separate completion grace period
  is a product-rule decision, not changed by this notification fix.
- A habit's snooze counter is stored against its current database occurrence.
  When several occurrences pass without opening the habits page, a background
  Snooze action can still encounter old occurrence state. Occurrence-specific
  transactional action handling remains follow-up work.
- Scheduling errors are logged but not surfaced to the user. Enabling a setting
  does not prove the OS accepted or will deliver its alarm. OEM battery controls,
  denied notification permission and exact-alarm permission changes require
  physical-device testing.
- Cross-device edits do not instantly cancel another device's already scheduled
  local notifications. Startup/resume refresh reconciles current task/habit data.
- Validation uses mocked notification platform calls, not actual Android delivery.
  Verify on-device: repeated launches after a mantra fires; habit Snooze with the
  app closed; early habit completion; task completion/deletion; reboot and denied
  exact-alarm permission.

Reference: [plugin Android setup and notification actions](https://pub.dev/packages/flutter_local_notifications).
