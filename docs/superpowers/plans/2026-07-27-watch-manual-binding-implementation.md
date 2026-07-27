# Watch Manual Binding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manual Watch binding action that sends protocol 3.4 over the existing BLE L1/L2 command channel and reports success, failure, timeout, and channel availability in the confirmed UI.

**Architecture:** Keep byte-level protocol handling in a pure Dart service and asynchronous state in an auto-disposed Riverpod `StateNotifier`. The Watch page only maps state to controls and SnackBars; the notifier receives transport callbacks so its behavior can be unit tested without a Bluetooth adapter.

**Tech Stack:** Dart, Flutter Material 3, Riverpod 2, existing `BleManager`/`L1Engine`, Flutter test

---

### Task 1: Binding Protocol

**Files:**
- Create: `lib/services/watch_bind_protocol.dart`
- Test: `test/services/watch_bind_protocol_test.dart`

- [ ] Write failing tests asserting `03 00 01 00 20 + userId`, rejection of non-32-byte IDs, strict parsing of `03 00 02 00 01 <status>`, and generation of 32-byte IDs.
- [ ] Run `flutter test test/services/watch_bind_protocol_test.dart` and confirm failure because the service does not exist.
- [ ] Implement `WatchBindProtocol.buildRequest`, `parseResponse`, `generateUserId`, and the process-lifetime debug User ID.
- [ ] Re-run the protocol tests and confirm they pass.

### Task 2: Binding State Controller

**Files:**
- Create: `lib/providers/watch_bind_provider.dart`
- Test: `test/providers/watch_bind_provider_test.dart`

- [ ] Write failing tests for unavailable transport, request transmission, duplicate-call suppression, unrelated frame filtering, success, nonzero device status, timeout, and disposal.
- [ ] Run `flutter test test/providers/watch_bind_provider_test.dart` and confirm failure because the controller does not exist.
- [ ] Implement `WatchBindPhase`, immutable `WatchBindState`, and `WatchBindNotifier` with injected availability/send/notification dependencies and an injectable timeout.
- [ ] Add an auto-disposed Riverpod provider wired to `bleManagerProvider`, with the process-lifetime User ID and an 8-second timeout.
- [ ] Re-run controller tests and confirm they pass.

### Task 3: Watch Page UI

**Files:**
- Modify: `lib/pages/watch/watch_device_page.dart`
- Create: `test/pages/watch/watch_device_page_test.dart`

- [ ] Write failing widget tests that assert `WiFi 配网` is absent, `绑定设备` is present, tapping invokes binding, and state changes render `绑定中...` then `已绑定`.
- [ ] Run `flutter test test/pages/watch/watch_device_page_test.dart` and confirm the old WiFi button causes the expected failure.
- [ ] Replace the WiFi button with a stable-width outlined binding button, progress indicator, state-specific icon/color/disabled behavior, and transition SnackBars.
- [ ] Re-run the widget tests and confirm they pass without overflow exceptions.

### Task 4: Verification

**Files:**
- Modify only files changed by formatting if required.

- [ ] Run `dart format lib/services/watch_bind_protocol.dart lib/providers/watch_bind_provider.dart lib/pages/watch/watch_device_page.dart test/services/watch_bind_protocol_test.dart test/providers/watch_bind_provider_test.dart test/pages/watch/watch_device_page_test.dart`.
- [ ] Run focused tests for all three new test files.
- [ ] Run the complete `flutter test` suite.
- [ ] Run `flutter analyze` and resolve all findings introduced by this change.
- [ ] Run `flutter build windows` and verify the executable is produced.
- [ ] Inspect `git diff --check`, repository status, and the final diff, then commit only the Watch binding implementation and tests.
