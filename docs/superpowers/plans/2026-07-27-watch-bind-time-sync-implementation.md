# Watch Bind Time Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send the phone's local calendar time after a successful watch bind, let firmware validate and store it in RTC, and allow the app to retry time synchronization without rebinding.

**Architecture:** A focused Dart encoder owns the packed SETTINGS frame while `WatchBindNotifier` keeps bind state and time-sync state separate. Firmware exposes a pure packed-time decoder in the SETTINGS handler and passes a validated calendar structure to `app_time`, which alone calls the Zephyr RTC driver.

**Tech Stack:** Flutter/Dart, Riverpod, Flutter tests, C, Zephyr RTC API, RTL8773G firmware build scripts.

---

### Task 1: Dart time protocol encoder

**Files:**
- Create: `test/services/watch_time_protocol_test.dart`
- Create: `lib/services/watch_time_protocol.dart`

- [ ] **Step 1: Write failing encoder tests**

Test that `WatchTimeProtocol.buildSetTime(DateTime(...))` produces the exact nine-byte frame `02 00 01 00 04 TT TT TT TT`, accepts years 2000 and 2063, and throws `ArgumentError` outside that range.

- [ ] **Step 2: Verify the tests fail for the missing encoder**

Run: `flutter test test/services/watch_time_protocol_test.dart`

Expected: compilation failure because `WatchTimeProtocol` does not exist.

- [ ] **Step 3: Implement the encoder**

Pack `(year - 2000)`, month, day, hour, minute, and second into a 32-bit integer with explicit shifts, then emit its bytes in big-endian order after the five-byte SETTINGS header.

- [ ] **Step 4: Verify the encoder tests pass**

Run: `flutter test test/services/watch_time_protocol_test.dart`

Expected: all encoder tests pass.

### Task 2: Bind-triggered sync state and retry

**Files:**
- Modify: `test/providers/watch_bind_provider_test.dart`
- Modify: `lib/providers/watch_bind_provider.dart`

- [ ] **Step 1: Write failing notifier tests**

Cover one time frame after bind success, no time frame after rejection/timeout/malformed/unrelated notifications, duplicate-success suppression, preservation of bind success when time sending returns `null` or throws, and retry using a fresh injected clock value without another bind request.

- [ ] **Step 2: Verify notifier tests fail for missing sync behavior**

Run: `flutter test test/providers/watch_bind_provider_test.dart`

Expected: assertions fail because the notifier neither sends time nor exposes a retryable time-sync state.

- [ ] **Step 3: Implement separate time-sync state**

Add `WatchTimeSyncPhase { notStarted, syncing, synced, failed }`, store it on `WatchBindState`, inject `DateTime Function() clock` with `DateTime.now` as the default, send time only after the first valid bind success, and add `retryTimeSync()` guarded by successful binding.

- [ ] **Step 4: Verify notifier tests pass**

Run: `flutter test test/providers/watch_bind_provider_test.dart`

Expected: all provider tests pass.

### Task 3: Synced and retry UI

**Files:**
- Modify: `test/pages/watch/watch_device_page_test.dart`
- Modify: `lib/pages/watch/watch_device_page.dart`

- [ ] **Step 1: Write failing widget tests**

Verify successful synchronization displays `设备绑定成功，时间已同步`; failed synchronization leaves `已绑定` visible and displays a `重试同步` action that sends only a new time frame.

- [ ] **Step 2: Verify widget tests fail for missing presentation**

Run: `flutter test test/pages/watch/watch_device_page_test.dart`

Expected: text/action assertions fail.

- [ ] **Step 3: Implement the time-sync presentation**

Keep the existing bind button behavior and add a compact retry action only when `timeSyncPhase == WatchTimeSyncPhase.failed`; route it to `retryTimeSync()`.

- [ ] **Step 4: Verify widget tests pass**

Run: `flutter test test/pages/watch/watch_device_page_test.dart`

Expected: all widget tests pass.

### Task 4: Firmware packed-time decoder

**Files:**
- Modify: `/home/howie_wang/hmi/rtl8773g-simple-test/applications/app/app_protocol/hmi_l2_cmd_settings.h`
- Modify: `/home/howie_wang/hmi/rtl8773g-simple-test/applications/app/app_protocol/hmi_l2_cmd_settings.c`
- Create: `/home/howie_wang/hmi/rtl8773g-simple-test/applications/tests/hmi_l2_time_decode_test.c`
- Create: `/home/howie_wang/hmi/rtl8773g-simple-test/applications/tests/run_hmi_l2_time_decode_test.sh`

- [ ] **Step 1: Add a failing host decoder test**

Exercise a known packed calendar, boundary years, invalid length/null input, invalid field ranges, invalid month/day pairs, rejected 2023-02-29, and accepted 2024-02-29.

- [ ] **Step 2: Verify the host test fails for the missing decoder**

Run: `bash tests/run_hmi_l2_time_decode_test.sh`

Expected: compile/link failure because `hmi_l2_decode_time` is missing.

- [ ] **Step 3: Implement explicit decode and validation**

Expose `hmi_l2_decode_time(const uint8_t *value, uint8_t value_len, app_time_local_t *out)`, decode big-endian bytes with shifts/masks, validate every field and leap-year month length, and route valid `HMI_L2_SET_TIME` values to `app_time_set_local`.

- [ ] **Step 4: Verify decoder tests pass**

Run: `bash tests/run_hmi_l2_time_decode_test.sh`

Expected: the host test exits zero.

### Task 5: Firmware RTC ownership

**Files:**
- Modify: `/home/howie_wang/hmi/rtl8773g-simple-test/applications/app/app_time/app_time.h`
- Modify: `/home/howie_wang/hmi/rtl8773g-simple-test/applications/app/app_time/app_time.c`

- [ ] **Step 1: Add the calendar RTC API**

Declare and implement `int app_time_set_local(const app_time_local_t *time)`. Obtain `DEVICE_DT_GET(DT_NODELABEL(rtc))`, require `device_is_ready`, map calendar values to `struct rtc_time` (`tm_year = year - 1900`, `tm_mon = month - 1`, `tm_wday/tm_yday = -1`, `tm_isdst = -1`), and return the `rtc_set_time` result.

- [ ] **Step 2: Keep RTC errors observable**

Log unavailable devices and failed writes while returning a nonzero result; log success without changing timezone semantics or the existing Unix-time declarations.

- [ ] **Step 3: Build the complete firmware**

Run the documented command from `scripts/README.md` for the current application configuration.

Expected: firmware compilation and link complete successfully.

### Task 6: Full verification and Windows artifact

**Files:**
- Verify only; do not modify generated build outputs.

- [ ] **Step 1: Format touched Dart files**

Run: `dart format lib/services/watch_time_protocol.dart lib/providers/watch_bind_provider.dart lib/pages/watch/watch_device_page.dart test/services/watch_time_protocol_test.dart test/providers/watch_bind_provider_test.dart test/pages/watch/watch_device_page_test.dart`

- [ ] **Step 2: Run all APP checks**

Run: `flutter test`, `flutter analyze`, and `git diff --check`.

Expected: each exits zero.

- [ ] **Step 3: Build the Windows release**

Run the README's Windows command with `TrackFileAccess=false`, the coroutine warning define, NuGet on `PATH`, and `--no-pub` when the existing junction setup requires it.

Expected artifact: `build/windows/x64/runner/Release/HoneyBox.exe`.

- [ ] **Step 4: Check firmware diff and build evidence**

Run: `git diff --check`, the host decoder test, and the firmware build again from the firmware repository.

Expected: clean diff checks, passing decoder test, and successful firmware build.
