# Watch Health App Design

## Goal

Replace the Watch health placeholder with a Flutter page for syncing and viewing
sample Watch health data on Android and Windows. The first version does not send
BLE commands, but its data source must be replaceable when the L2 contract is
available.

## Architecture

`WatchHealthRepository` is the boundary between UI state and transport. The
initial `MockWatchHealthRepository` returns deterministic sample data after a
short delay. `WatchHealthNotifier` owns sync status and the selected trend
period. The page reads both through Riverpod and never depends on mock details.

The route passes the connected device name and device ID to `WatchHealthPage`.
The device ID is retained for a future repository implementation; only the name
is displayed in this version.

## Interface

The page follows the approved HTML prototype:

- App bar with a sync action.
- Device, battery, and last-sync status.
- Steps, heart rate, sleep, and active-duration summary tiles.
- Day, week, and month steps/heart-rate trends.
- Sleep-stage distribution and recent records.
- Empty, syncing, success, and failure feedback.

Charts use Flutter `CustomPainter`, avoiding a new chart dependency. The layout
uses a constrained content width on desktop and a single scrolling column on
mobile.

## Testing

Provider tests verify initial state, successful synchronization, failures, and
period selection. Widget tests verify the empty state, sync interaction, trend
switching, device-name rendering, and narrow-screen layout. The full Flutter
test suite, analyzer, and Windows release build are the completion gates.
