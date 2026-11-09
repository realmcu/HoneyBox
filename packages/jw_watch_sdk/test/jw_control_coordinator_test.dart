import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/src/connection/jw_protocol.dart';
import 'package:jw_watch_sdk/src/control/jw_control_coordinator.dart';
import 'package:jw_watch_sdk/src/control/jw_control_listener.dart';
import 'package:jw_watch_sdk/src/control/jw_control_protocol.dart';

void main() {
  test('coordinator merges find-phone keys into enable callback', () {
    final coordinator = JWControlCoordinator.testing();
    final findPhone = <bool>[];
    coordinator.addListener(_Listener(findPhone: findPhone.add));

    coordinator.handleMessage(JWProtocolMessage(
        7, JWControlProtocol.findPhoneRsp, Uint8List(0)));
    coordinator.handleMessage(JWProtocolMessage(
        7, JWControlProtocol.findPhoneRsp2, Uint8List.fromList([1])));
    coordinator.handleMessage(JWProtocolMessage(
        7, JWControlProtocol.findPhoneRsp2, Uint8List.fromList([0])));

    expect(findPhone, [true, true, false]);
    coordinator.dispose();
  });

  test('coordinator forwards music control and take photo', () {
    final coordinator = JWControlCoordinator.testing();
    var takePhotoCount = 0;
    var musicControl = -1;
    coordinator.addListener(_Listener(
      onTakePhoto: () => takePhotoCount++,
      onMusic: (c) => musicControl = c,
    ));

    coordinator.handleMessage(
        JWProtocolMessage(7, JWControlProtocol.photoRsp, Uint8List(0)));
    coordinator.handleMessage(JWProtocolMessage(
        7, JWControlProtocol.musicControl, Uint8List.fromList([4])));

    expect(takePhotoCount, 1);
    expect(musicControl, 4);
    coordinator.dispose();
  });
}

final class _Listener implements JWControlListener {
  _Listener({void Function(bool enable)? findPhone, void Function()? onTakePhoto, void Function(int control)? onMusic})
      : _findPhone = findPhone,
        _onTakePhoto = onTakePhoto,
        _onMusic = onMusic;

  final void Function(bool enable)? _findPhone;
  final void Function()? _onTakePhoto;
  final void Function(int control)? _onMusic;

  @override
  void onFindPhone({required bool enable}) => _findPhone?.call(enable);

  @override
  void onMusicControl(int control) => _onMusic?.call(control);

  @override
  void onTakePhoto() => _onTakePhoto?.call();
}
