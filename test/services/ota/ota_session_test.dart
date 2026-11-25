import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ota/ota_session.dart';

void main() {
  test('awaiting user confirmation does not expire the preparing timeout', () {
    var now = DateTime(2026, 11, 23, 12);
    final session = OtaSession(
      'session',
      now: () => now,
      phaseTimeouts: const {OtaPhase.preparing: Duration(seconds: 60)},
    );

    expect(
      session.apply(
        const OtaEvent(sessionId: 'session', phase: OtaPhase.preparing),
      ),
      isTrue,
    );
    expect(
      session.apply(
        const OtaEvent(sessionId: 'session', phase: OtaPhase.checking),
      ),
      isTrue,
    );
    expect(
      session.apply(
        const OtaEvent(
          sessionId: 'session',
          phase: OtaPhase.awaitingConfirmation,
        ),
      ),
      isTrue,
    );

    now = now.add(const Duration(minutes: 10));

    expect(session.checkTimeout(), isFalse);
    expect(session.outcome, isNull);
    expect(
      session.apply(
        const OtaEvent(sessionId: 'session', phase: OtaPhase.connecting),
      ),
      isTrue,
    );
  });
}
