import '../model/jw_session_state.dart';
import 'jw_session.dart';

/// Immutable view of one Hub entry. Closing entries remain visible until the
/// transport lease and history writer have been released successfully.
final class JWAttachedSession {
  const JWAttachedSession({
    required this.deviceId,
    required this.session,
    required this.state,
    required this.isSimulated,
    required this.isClosing,
    this.closeError,
  });

  final String deviceId;
  final JWWatchSession session;
  final JWSessionState state;
  final bool isSimulated;
  final bool isClosing;
  final Object? closeError;
}
