import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:watch_frame_channel/watch_frame_channel.dart';
import 'package:watch_transport_simulation/watch_transport_simulation.dart';

import '../connection/jw_protocol.dart';

/// Persistent per-watch state. Use a distinct instance for every simulated ID.
/// Supports authentication, scalar settings, capabilities and heart history.
final class JWSimWatchState {
  JWSimWatchState({this.heartRate = 70});
  final int heartRate;
  String? boundUserId;
  int language = 1;
  int hourSystem = 0;
  int unitSystem = 0;
  bool historyConfirmed = false;
}

WatchSimulationDevice jwSimWatchDevice({
  required String id,
  required String name,
  required JWSimWatchState state,
}) =>
    WatchSimulationDevice(
      id: id,
      name: name,
      attach: (peer) {
        final channel = WatchFrameChannel(
          WatchFramePort.fromConnection(peer),
          profile: WatchFrameProfile.jw,
          config: const WatchFrameConfig(maxPayloadLength: 236),
        );
        var stopped = false;
        Future<void> reply(int command, int key, List<int> value) async {
          if (stopped) return;
          await channel
              .startSend(encodeJWRequest(JWProtocolRequest(
                command: command,
                key: key,
                responseKey: null,
                value: Uint8List.fromList(value),
              )))
              .completed;
        }

        Future<void> handle(JWProtocolMessage message) async {
          if (message.command == 3) {
            final identity = ascii.decode(message.value);
            if (message.key == 1) {
              state.boundUserId = identity;
              await reply(3, 2, [0]);
            } else if (message.key == 3) {
              await reply(3, 4, [state.boundUserId == identity ? 0 : 1]);
            } else if (message.key == 5) {
              state.boundUserId = null;
            }
          } else if (message.command == 2) {
            switch (message.key) {
              case 0x36:
                // multiLanguage/hourSystem/unitSystem; heart history only.
                await reply(2, 0x37, [0, 0, 0x38, 0x04, 0, 0, 0, 0]);
              case 0x4e:
                state.language = message.value.single;
              case 0x4f:
                await reply(2, 0x50, [state.language]);
              case 0x41:
                state.hourSystem = message.value.single;
              case 0x42:
                await reply(2, 0x43, [state.hourSystem]);
              case 0x44:
                state.unitSystem = message.value.single;
              case 0x45:
                await reply(2, 0x46, [state.unitSystem]);
            }
          } else if (message.command == 6 && message.key == 0x3d) {
            await reply(6, 0x3e, [0]);
          } else if (message.command == 5) {
            if (message.key == 1) {
              await reply(5, 7, [2, 0, 1]);
              final now = DateTime.now();
              final bytes = ByteData(12);
              bytes.setUint16(
                  0, ((now.year - 2000) << 9) | (now.month << 5) | now.day);
              bytes.setUint64(
                  4, ((now.hour * 60 + now.minute) << 16) | state.heartRate);
              await reply(5, 0x1b, bytes.buffer.asUint8List());
              await reply(5, 8, []);
            } else if (message.key == 0x1c) {
              state.historyConfirmed = true;
            } else if (message.key == 0xfa) {
              state.historyConfirmed = false;
            }
          }
        }

        Future<void> tail = Future.value();
        final subscription = channel.payloads.listen((payload) {
          tail = tail.then((_) async {
            for (final message in decodeJWMessages(payload.bytes)) {
              if (stopped) return;
              await handle(message);
            }
          }).catchError((Object _) {
            /* Peer shutdown cancels device replies. */
          });
        });
        return WatchSimulationDeviceSession(dispose: () async {
          stopped = true;
          await subscription.cancel();
          await channel.close();
          await tail;
        });
      },
    );
