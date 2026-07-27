# Watch Bind Time Sync Design

## Goal

After the app receives a successful watch bind response, it immediately sends
the phone's current local date and time to the firmware. Binding and time sync
remain separate outcomes: a time-send failure must not turn a completed bind
into a bind failure.

This change covers both repositories:

- Flutter app: `C:\Users\howie_wang.RSDOMAIN\workspace\hmi-android-apk`
- Firmware: `/home/howie_wang/hmi/rtl8773g-simple-test/applications`

## Protocol

The implementation follows `BLE_PROTOCOL_SPEC.md` in the firmware workspace.
All multi-byte values are big-endian.

The time-setting L2 frame is:

```text
02 00 01 00 04 TT TT TT TT
|  |  |  |     |
|  |  |  |     +-- 32-bit packed local date/time, big-endian
|  |  |  +-------- value length = 4
|  |  +----------- key = time setting (0x01)
|  +-------------- L2 version/reserved = 0
+----------------- command = settings (0x02)
```

The packed 32-bit value uses these fields:

| Bits | Field | Valid range |
| --- | --- | --- |
| 31:26 | Year offset from 2000 | 0..63 |
| 25:22 | Month | 1..12 |
| 21:17 | Day | 1..31, valid for month/year |
| 16:12 | Hour | 0..23 |
| 11:6 | Minute | 0..59 |
| 5:0 | Second | 0..59 |

The protocol has no timezone field. The app therefore sends `DateTime.now()`
as local wall-clock time, and the firmware stores that same local wall-clock
value in the RTC. Supported years are 2000 through 2063 inclusive.

The existing protocol defines no application-level response for time setting.
The app treats successful submission to the existing L2/L1 send path as a
successful time sync request. This change does not introduce a new response
key or alter the wire protocol.

## App Design

### Encoding

Add a focused protocol encoder that accepts a local `DateTime`, validates the
supported year, packs the six fields, and builds the complete L2 settings
frame. Keeping this separate from binding encoding makes the wire format
independently testable.

The current time is injected into `WatchBindNotifier` through a clock callback
for deterministic tests. Production uses `DateTime.now`.

### Binding flow

The binding flow remains unchanged until a valid firmware response is parsed:

1. App sends the existing bind request.
2. App ignores unrelated or malformed notifications.
3. A nonzero bind result remains a retryable bind failure and sends no time.
4. A zero bind result permanently records bind success for this notifier.
5. App builds and sends one time-setting frame using the current local time.

Duplicate bind responses received after the first accepted success do not send
time again.

### State and UI

Binding and time sync are represented separately. The UI behavior is:

| Outcome | Bind presentation | Time presentation | Available action |
| --- | --- | --- | --- |
| Bind in progress | `绑定中...` | None | None |
| Bind failed | `重新绑定` | None | Retry binding |
| Bind succeeded, time sent | `已绑定` | `设备绑定成功，时间已同步` | None |
| Bind succeeded, time send failed | `已绑定` | `设备绑定成功，时间同步失败` | `重试同步` |

Retrying time sync sends only a fresh time-setting frame. It never sends a
second bind request. If the command channel is unavailable during retry, the
state remains bound and time sync remains failed.

Disposal continues to cancel the bind response timer and notification
subscription. Time sending is synchronous through the current `sendCommand`
interface, so it adds no new timer or subscription.

## Firmware Design

### Settings decoder

Extend `hmi_l2_cmd_settings.c` to handle `HMI_L2_SET_TIME`:

1. Require a non-null value of exactly four bytes.
2. Read the packed value in big-endian order.
3. Decode year, month, day, hour, minute, and second by explicit shifts and
   masks. Do not rely on compiler-specific C bitfield layout.
4. Validate all ranges, including the actual number of days in the decoded
   month and leap-year handling.
5. Pass a calendar value to the `app_time` module.
6. Log malformed payloads and RTC write failures without crashing the protocol
   task.

Other settings keys keep their existing logging behavior.

### RTC ownership

`app_time` owns the Zephyr RTC interaction. Add a calendar-based API used by
the settings handler. It converts the protocol calendar fields to
`struct rtc_time` and calls `rtc_set_time` on `DT_NODELABEL(rtc)` after checking
that the device is ready.

The protocol handler does not include RTC driver details. This keeps BLE/L2
parsing independent from the hardware implementation and gives future time
sources one ownership point.

The existing Unix-seconds/timezone declarations in `app_time.h` are outside
this feature's wire format and are not used to reinterpret the local calendar
payload.

## Error Handling

- App bind timeout or rejection: no time frame is sent.
- App time encoding failure: binding stays successful; time sync is failed.
- App `sendCommand` throws or returns null: binding stays successful; time sync
  is failed and can be retried.
- Firmware value length is not four: ignore the setting and log the reason.
- Firmware date or time is invalid: do not modify RTC; log the decoded value.
- RTC device is unavailable or `rtc_set_time` fails: retain the previous RTC
  value and log the driver error.

## Tests

### Flutter

- Encoder produces an exact frame for a fixed local date/time.
- Encoder covers lower and upper supported years and rejects years outside
  2000..2063.
- Bind rejection, timeout, malformed notification, and unrelated notification
  do not send a time frame.
- Bind success sends exactly one time frame after the bind request.
- Duplicate success notifications do not send duplicate time frames.
- A failed time send preserves bind success and exposes retry.
- Retry sends only a new time frame using the current clock value.
- Widget tests cover the synced and retry-sync presentations.

### Firmware

- A host-testable decode function accepts known packed values.
- Invalid lengths, invalid field ranges, invalid month/day combinations, and
  non-leap-year February 29 are rejected.
- Leap-year February 29 is accepted.
- The settings handler routes a valid decoded calendar value to `app_time`.
- The firmware application builds successfully with the Zephyr RTC API.

## Acceptance Criteria

1. A successful bind response causes one correctly encoded local-time frame.
2. No unsuccessful or unrelated response triggers time sync.
3. Time-send failure never changes the completed bind into a bind failure.
4. The user can retry only time sync after such a failure.
5. Firmware validates and writes a valid time to RTC without compiler bitfield
   assumptions.
6. Existing Flutter tests, new Flutter tests, firmware tests where available,
   and the complete firmware build pass.
