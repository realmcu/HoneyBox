import '../model/ws_session_state.dart';
import 'ws_session.dart';

/// Immutable view of one Hub entry. Closing entries remain visible until the
/// transport lease and history writer have been released successfully.
final class WSAttachedSession {
  const WSAttachedSession({
    required this.deviceId,
    required this.session,
    required this.state,
    required this.isSimulated,
    required this.isClosing,
    this.closeError,
  });

  final String deviceId;
  final WSWatchSession session;
  final WSSessionState state;
  final bool isSimulated;
  final bool isClosing;
  final Object? closeError;
}
