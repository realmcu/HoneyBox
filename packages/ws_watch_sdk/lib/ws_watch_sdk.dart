/// wo-smart 手表 BLE 私有协议 Flutter SDK。
library;

export 'src/ble/gatt_profile.dart';
export 'src/config.dart';
export 'src/connection/connection_state.dart';
export 'src/errors.dart';
export 'src/logger.dart';
export 'src/version.dart';
export 'src/watch.dart';

export 'src/debug/debug_api.dart' show WSDebugApi, WSRawRequest, WSProtocolView;
export 'src/debug/models.dart';
export 'src/protocol/address.dart';
export 'src/protocol/status.dart';

export 'src/model/frame.dart';

export 'src/scanner.dart';
export 'src/capability/capabilities.dart';
export 'src/model/feature.dart';
export 'src/model/device_info.dart';
export 'src/connection/user_id.dart';
export 'src/simulation/sim_watch_session.dart' show kWsWatchSimDeviceId;
