import '../connection/jw_protocol.dart';
import 'jw_control_codec.dart';
import 'jw_music_status_info.dart';
import 'jw_weather_info.dart';

/// `cmd 0x07` keys aligned with Android V2 `BleProtocol.ControlKey`.
abstract final class JWControlProtocol {
  static const command = 7;

  static const photoRsp = 0x01;
  static const findPhoneRsp = 0x02;
  static const appReq = 0x11;
  static const musicControl = 0x18;
  static const musicStatus = 0x19;
  static const findPhoneRsp2 = 0x1c;
  static const weatherSet = 0x20;

  static JWProtocolRequest setTakePhotoControl(bool enable) =>
      JWProtocolRequest(
        command: command,
        key: appReq,
        responseKey: null,
        value: JWControlCodec.encodeTakePhotoControl(enable),
      );

  static JWProtocolRequest setMusicStatus(JWMusicStatusInfo info) =>
      JWProtocolRequest(
        command: command,
        key: musicStatus,
        responseKey: null,
        value: JWControlCodec.encodeMusicStatus(info),
      );

  static JWProtocolRequest setWeather(JWWeatherInfo info) => JWProtocolRequest(
        command: command,
        key: weatherSet,
        responseKey: null,
        value: JWControlCodec.encodeWeather(info),
      );
}
