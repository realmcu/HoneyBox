import 'dart:async';

// Exercise BleManager's actual flutter_blue_plus binding without a radio.
// The interface is provided by flutter_blue_plus's existing dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honeybox/services/ble_manager.dart';
import 'package:honeybox/services/jw/jw_gatt_profile.dart';

final class _BlePlatform extends FlutterBluePlusPlatform {
  final connections = StreamController<BmConnectionStateResponse>.broadcast();
  final services = StreamController<BmDiscoverServicesResult>.broadcast();
  final disconnectedIds = <String>[];
  final descriptors = StreamController<BmDescriptorData>.broadcast();

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged =>
      connections.stream;
  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices => services.stream;
  @override
  Stream<BmDescriptorData> get onDescriptorWritten => descriptors.stream;
  @override
  Future<BmBluetoothAdapterState> getAdapterState(
          BmBluetoothAdapterStateRequest request) async =>
      BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);

  void emitState(DeviceIdentifier id, BmConnectionStateEnum state) {
    connections.add(BmConnectionStateResponse(
        remoteId: id,
        connectionState: state,
        disconnectReasonCode: null,
        disconnectReasonString: null));
  }

  @override
  Future<bool> connect(BmConnectRequest request) async {
    emitState(request.remoteId, BmConnectionStateEnum.connected);
    return true;
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) async {
    disconnectedIds.add(request.remoteId.str);
    emitState(request.remoteId, BmConnectionStateEnum.disconnected);
    return true;
  }

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) async {
    final id = request.remoteId;
    final uuid = Guid(JwGattProfile.service);
    BmBluetoothCharacteristic characteristic(String value,
            {bool write = false, bool notify = false}) =>
        BmBluetoothCharacteristic(
            remoteId: id,
            primaryServiceUuid: null,
            serviceUuid: uuid,
            characteristicUuid: Guid(value),
            instanceId: 0,
            descriptors: [],
            properties: BmCharacteristicProperties(
                broadcast: false,
                read: false,
                writeWithoutResponse: false,
                write: write,
                notify: notify,
                indicate: false,
                authenticatedSignedWrites: false,
                extendedProperties: false,
                notifyEncryptionRequired: false,
                indicateEncryptionRequired: false));
    services.add(BmDiscoverServicesResult(
        remoteId: id,
        services: [
          BmBluetoothService(
              remoteId: id,
              primaryServiceUuid: null,
              serviceUuid: uuid,
              characteristics: [
                characteristic('FF02', write: true),
                characteristic('FF03', notify: true)
              ])
        ],
        success: true,
        errorCode: 0,
        errorString: ''));
    return true;
  }

  @override
  Future<bool> setNotifyValue(BmSetNotifyValueRequest request) async {
    descriptors.add(BmDescriptorData(
        remoteId: request.remoteId,
        primaryServiceUuid: request.primaryServiceUuid,
        serviceUuid: request.serviceUuid,
        characteristicUuid: request.characteristicUuid,
        instanceId: request.instanceId,
        descriptorUuid: Guid('2902'),
        value: [1, 0],
        success: true,
        errorCode: 0,
        errorString: ''));
    return true;
  }

  Future<void> close() async {
    await connections.close();
    await services.close();
    await descriptors.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('late old JW disconnect cannot disconnect a replacement connection',
      () async {
    final platform = _BlePlatform();
    FlutterBluePlusPlatform.instance = platform;
    final manager = BleManager();
    addTearDown(() async {
      manager.dispose();
      await platform.close();
    });

    expect(await manager.connect('old-device', 'S200', allowJw: true), isTrue);
    final oldPort = manager.jwTransport!;
    // A radio disconnect invalidates the old port before deferred session close.
    platform.emitState(const DeviceIdentifier('old-device'),
        BmConnectionStateEnum.disconnected);
    await Future<void>.delayed(Duration.zero);
    expect(manager.state, BleState.disconnected);

    expect(await manager.connect('replacement', 'S200', allowJw: true), isTrue);
    final replacementPort = manager.jwTransport;
    await oldPort.disconnect();
    expect(platform.disconnectedIds, isEmpty);
    expect(manager.state, BleState.connected);
    expect(manager.jwTransport, same(replacementPort));
    expect(manager.deviceId, 'replacement');

    // The active port must still be able to close its own connection.
    await replacementPort!.disconnect();
    expect(platform.disconnectedIds, ['replacement']);
    expect(manager.state, BleState.disconnected);
  });
}
