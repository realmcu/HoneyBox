import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jw_watch_sdk/src/connection/jw_protocol.dart';
import 'package:jw_watch_sdk/src/control/jw_control_codec.dart';
import 'package:jw_watch_sdk/src/control/jw_control_protocol.dart';
import 'package:jw_watch_sdk/src/control/jw_music_status_info.dart';
import 'package:jw_watch_sdk/src/control/jw_weather_info.dart';

void main() {
  test('control commands match Android V2 FunctionPacketHelper', () {
    expect(
      encodeJWRequest(JWControlProtocol.setTakePhotoControl(true)),
      Uint8List.fromList([7, 0, 0x11, 0, 1, 1]),
    );
    expect(
      encodeJWRequest(JWControlProtocol.setTakePhotoControl(false)),
      Uint8List.fromList([7, 0, 0x11, 0, 1, 0]),
    );
    expect(
      encodeJWRequest(JWControlProtocol.setMusicStatus(
        const JWMusicStatusInfo(
          hasPlayer: true,
          playing: false,
          volumePercent: 10,
        ),
      )),
      Uint8List.fromList([7, 0, 0x19, 0, 1, 0xca]),
    );
  });

  test('music status bit layout matches ApplicationLayerMusicPlayerPacket', () {
    final bytes = JWControlCodec.encodeMusicStatus(
      const JWMusicStatusInfo(
        hasPlayer: true,
        playing: true,
        volumePercent: 5,
      ),
    );
    expect(bytes.single, 0x85);
  });

  test('weather packet uses enable and city utf8 layout', () {
    final info = JWWeatherInfo(
      enable: true,
      year: 2026,
      month: 11,
      day: 9,
      city: '上海',
      currentWeather: const JWCurrentWeather(
        weatherCode: JWWeatherInfo.weatherCodeSunny,
        temperature: 22,
        maxTemperature: 26,
        minTemperature: 18,
        humidity: 50,
        ultravioletIntensity: 3,
        pollutionIndex: 2,
      ),
    );
    final value = JWControlCodec.encodeWeather(info);
    expect(value.length, 64);
    expect(value[0], 1);
    expect(value[1], 0x07);
    expect(value[2], 0xea);
    expect(value[3], 11);
    expect(value[4], 9);
    expect(value[39], JWWeatherInfo.weatherCodeSunny);
    expect(value[40], 22);
  });
}
