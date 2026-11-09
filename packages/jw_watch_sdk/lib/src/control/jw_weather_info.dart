/// Mirrors Android V2 `JWWeatherInfo` (`cmd 0x07` / key `0x20`).
final class JWWeatherInfo {
  JWWeatherInfo({
    required this.enable,
    this.year = 0,
    this.month = 0,
    this.day = 0,
    this.city = '',
    this.currentWeather,
    this.nextOneDayWeather,
    this.nextTwoDayWeather,
    this.nextThreeDayWeather,
    this.nextFourDayWeather,
    this.nextFiveDayWeather,
    this.nextSixDayWeather,
  });

  static const weatherCodeOther = 0x00;
  static const weatherCodeSunny = 0x01;
  static const weatherCodeCloudy = 0x02;
  static const weatherCodeOvercast = 0x03;
  static const weatherCodeRain = 0x04;
  static const weatherCodeLightRain = 0x05;
  static const weatherCodeModerateRain = 0x06;
  static const weatherCodeHeavyRain = 0x07;
  static const weatherCodeStorm = 0x08;
  static const weatherCodeShowerRain = 0x09;
  static const weatherCodeHeavyShowerRain = 0x0a;
  static const weatherCodeFreezingRain = 0x0b;
  static const weatherCodeSnow = 0x0c;
  static const weatherCodeLightSnow = 0x0d;
  static const weatherCodeModerateSnow = 0x0e;
  static const weatherCodeHeavySnow = 0x0f;
  static const weatherCodeSleet = 0x10;
  static const weatherCodeTyphoon = 0x11;
  static const weatherCodeSandstorm = 0x12;
  static const weatherCodeSunnyAtNight = 0x13;
  static const weatherCodeCloudyAtNight = 0x14;
  static const weatherCodeHot = 0x15;
  static const weatherCodeCold = 0x16;
  static const weatherCodeBreeze = 0x17;
  static const weatherCodeGale = 0x18;
  static const weatherCodeMist = 0x19;
  static const weatherCodeCloudyToClear = 0x1a;

  /// Weather push master switch (Android `JWWeatherInfo.isOpen`).
  final bool enable;
  final int year;
  final int month;
  final int day;
  final String city;
  final JWCurrentWeather? currentWeather;
  final JWFutureWeather? nextOneDayWeather;
  final JWFutureWeather? nextTwoDayWeather;
  final JWFutureWeather? nextThreeDayWeather;
  final JWFutureWeather? nextFourDayWeather;
  final JWFutureWeather? nextFiveDayWeather;
  final JWFutureWeather? nextSixDayWeather;
}

final class JWCurrentWeather {
  const JWCurrentWeather({
    required this.weatherCode,
    required this.temperature,
    required this.maxTemperature,
    required this.minTemperature,
    required this.humidity,
    required this.ultravioletIntensity,
    required this.pollutionIndex,
  });

  final int weatherCode;
  final int temperature;
  final int maxTemperature;
  final int minTemperature;
  final int humidity;
  final int ultravioletIntensity;
  final int pollutionIndex;
}

final class JWFutureWeather {
  const JWFutureWeather({
    required this.weatherCode,
    required this.maxTemperature,
    required this.minTemperature,
  });

  final int weatherCode;
  final int maxTemperature;
  final int minTemperature;
}
