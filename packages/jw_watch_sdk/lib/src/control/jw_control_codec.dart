import 'dart:convert';
import 'dart:typed_data';

import 'jw_music_status_info.dart';
import 'jw_weather_info.dart';

/// Encoders aligned with Android V2 `FunctionPacketHelper` control keys.
abstract final class JWControlCodec {
  static Uint8List encodeTakePhotoControl(bool enable) =>
      Uint8List.fromList([enable ? 0x01 : 0x00]);

  static Uint8List encodeMusicStatus(JWMusicStatusInfo info) {
    var value = 0;
    if (info.hasPlayer) {
      value |= 0x80;
    }
    if (!info.playing) {
      value |= 0x40;
    }
    value |= info.volumePercent & 0x3f;
    return Uint8List.fromList([value & 0xff]);
  }

  static Uint8List encodeWeather(JWWeatherInfo weatherInfo) {
    final keyValue = Uint8List(64);
    keyValue[0] = weatherInfo.enable ? 0x01 : 0x00;
    keyValue[1] = (weatherInfo.year >> 8) & 0xff;
    keyValue[2] = weatherInfo.year & 0xff;
    keyValue[3] = weatherInfo.month & 0xff;
    keyValue[4] = weatherInfo.day & 0xff;

    final cityBytes = _utf8City(weatherInfo.city, 34);
    keyValue.setRange(5, 5 + cityBytes.length, cityBytes);

    final current = weatherInfo.currentWeather;
    keyValue[39] = _clampWeatherCode(current?.weatherCode ?? 0);
    keyValue[40] = current?.temperature ?? 0;
    keyValue[41] = current?.maxTemperature ?? 0;
    keyValue[42] = current?.minTemperature ?? 0;
    keyValue[43] = current?.humidity ?? 0;
    keyValue[44] = current?.ultravioletIntensity ?? 0;
    keyValue[45] = current?.pollutionIndex ?? 0;

    _writeFuture(keyValue, 46, weatherInfo.nextOneDayWeather);
    _writeFuture(keyValue, 49, weatherInfo.nextTwoDayWeather);
    _writeFuture(keyValue, 52, weatherInfo.nextThreeDayWeather);
    _writeFuture(keyValue, 55, weatherInfo.nextFourDayWeather);
    _writeFuture(keyValue, 58, weatherInfo.nextFiveDayWeather);
    _writeFuture(keyValue, 61, weatherInfo.nextSixDayWeather);

    return keyValue;
  }

  static int _clampWeatherCode(int code) {
    if (code < JWWeatherInfo.weatherCodeOther ||
        code > JWWeatherInfo.weatherCodeCloudyToClear) {
      return JWWeatherInfo.weatherCodeOther;
    }
    return code & 0xff;
  }

  static void _writeFuture(Uint8List buffer, int offset, JWFutureWeather? day) {
    buffer[offset] = _clampWeatherCode(day?.weatherCode ?? 0);
    buffer[offset + 1] = day?.maxTemperature ?? 0;
    buffer[offset + 2] = day?.minTemperature ?? 0;
  }

  static Uint8List _utf8City(String city, int byteCount) {
    final out = Uint8List(byteCount);
    if (city.isEmpty) {
      return out;
    }
    final encoded = utf8.encode(city);
    final maxContent = byteCount - 1;
    if (encoded.length <= maxContent) {
      out.setRange(0, encoded.length, encoded);
      return out;
    }
    var end = maxContent;
    while (end > 0 && (encoded[end] & 0xc0) == 0x80) {
      end--;
    }
    out.setRange(0, end, encoded.sublist(0, end));
    return out;
  }
}
