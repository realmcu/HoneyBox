import 'package:flutter_test/flutter_test.dart';
import 'package:watch_transport/watch_transport.dart';

void main() {
  test('endpoint identity includes transport, not just device ID', () {
    final a = WatchDeviceTarget(transportId: 'ble', deviceId: 'a');
    final b = WatchDeviceTarget(transportId: 'ble', deviceId: 'a');
    final c = WatchDeviceTarget(transportId: 'simulation', deviceId: 'a');
    expect(a, b);
    expect({a, b, c}, hasLength(2));
  });
  test('empty targets and nonpositive write limits are rejected', () {
    expect(() => WatchDeviceTarget(transportId: '', deviceId: 'a'),
        throwsArgumentError);
    expect(() => WatchDeviceTarget(transportId: 'ble', deviceId: ' '),
        throwsArgumentError);
    expect(() => WatchWriteLimits(maxWriteLength: 0), throwsArgumentError);
    expect(WatchWriteLimits(maxWriteLength: 3).maxWriteLength, 3);
  });
}
