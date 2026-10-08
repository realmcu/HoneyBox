import '../../services/jw/jw_configuration.dart';

const jwConsoleCategories = [
  '设备与基础',
  '健康测量',
  '自动监测',
  '提醒与闹钟',
  '运动',
  '资料与目标',
  '辅助控制',
  '历史数据'
];

class JwConsoleField {
  final String name, label, initial;
  final Map<String, String>? options;
  const JwConsoleField(this.name, this.label,
      [this.initial = '', this.options]);
}

class JwConsoleOperation {
  final String id, label, capability, note;
  final int category;
  final bool write;
  final List<JwConsoleField> fields;
  final String? blocked;
  const JwConsoleOperation(this.id, this.label, this.category,
      {this.capability = '',
      this.note = '',
      this.write = false,
      this.fields = const [],
      this.blocked});
}

const _binary = {'0': '关闭', '1': '开启'};
const _enabled = JwConsoleField('enabled', '开关', '0', _binary);
const _timeFields = [
  JwConsoleField('startHour', '开始时（0–23）', '8'),
  JwConsoleField('startMinute', '开始分（0–59）', '0'),
  JwConsoleField('endHour', '结束时（0–23）', '20'),
  JwConsoleField('endMinute', '结束分（0–59）', '0')
];
const _alarmFields = [
  JwConsoleField('date', '日期（YYYY-MM-DD，2000–2063）'),
  JwConsoleField('hour', '时（0–23）', '8'),
  JwConsoleField('minute', '分（0–59）', '0'),
  JwConsoleField('id', '闹钟 ID（0–7）', '0'),
  JwConsoleField('repeat', '星期掩码（0–127，0=单次）', '0')
];
const jwConsoleDomainLabels = {
  JwConfigurationDomain.hourSystem: '时制',
  JwConfigurationDomain.distanceUnit: '距离单位',
  JwConfigurationDomain.screenLightTime: '亮屏时长',
  JwConfigurationDomain.screenBrightness: '屏幕亮度',
  JwConfigurationDomain.heartRateAuto: '自动心率',
  JwConfigurationDomain.bloodOxygenAuto: '自动血氧',
  JwConfigurationDomain.bloodPressureAuto: '自动血压 / 血压显示',
  JwConfigurationDomain.temperatureConfig: '温度显示 / 补偿 / 单位',
};
final jwConsoleOperations = <JwConsoleOperation>[
  const JwConsoleOperation('history-sync', '完整轮次同步', 7, write: true),
  const JwConsoleOperation('history-reset', '全部游标重置', 7, write: true),
  const JwConsoleOperation('battery', '读取当前电量', 0),
  const JwConsoleOperation('language-read', '读取当前语言', 0,
      capability: 'languages'),
  const JwConsoleOperation('language-set', '设置语言并读回', 0,
      capability: 'languages',
      write: true,
      fields: [
        JwConsoleField(
            'value', '语言', '0', {'0': 'English', '1': '简体中文', '2': '繁體中文'})
      ]),
  const JwConsoleOperation('time', '同步手机当前时间', 0,
      write: true, note: '仅提交 / ACK，无独立时间读回接口。'),
  for (final d in JwConfigurationDomain.values) ...[
    JwConsoleOperation('config-${d.name}-read', '读取${jwConsoleDomainLabels[d]}',
        d.isScalar ? 0 : 2,
        capability: d.name),
    JwConsoleOperation('config-${d.name}-set',
        '设置${jwConsoleDomainLabels[d]}并读回', d.isScalar ? 0 : 2,
        capability: d.name,
        write: true,
        note: d.isMonitor ? '当前固件未定义可配置的分钟间隔。' : '先单项读取原值，再提交；未知位阻止写入。',
        fields: switch (d) {
          JwConfigurationDomain.hourSystem => const [
              JwConsoleField('value', '时制', '0', {'0': '24 小时', '1': '12 小时'})
            ],
          JwConfigurationDomain.distanceUnit => const [
              JwConsoleField('value', '距离单位', '0', {'0': '公里', '1': '英里'})
            ],
          JwConfigurationDomain.screenLightTime => const [
              JwConsoleField('value', '秒（3–30）', '10')
            ],
          JwConfigurationDomain.screenBrightness => const [
              JwConsoleField('value', '百分比（20–100）', '50')
            ],
          JwConfigurationDomain.bloodPressureAuto => const [
              _enabled,
              JwConsoleField('display', '血压显示', '0', _binary)
            ],
          JwConfigurationDomain.temperatureConfig => const [
              JwConsoleField('display', '温度显示', '0', _binary),
              JwConsoleField('compensate', '温度补偿', '0', _binary),
              JwConsoleField('celsius', '温度单位', '1', {'1': '摄氏度', '0': '华氏度'})
            ],
          _ => const [_enabled],
        }),
  ],
  const JwConsoleOperation('health', '读取健康模式状态', 1, capability: 'healthStatus'),
  const JwConsoleOperation('heart-stream-start', '开始实时心率', 1,
      capability: 'heartRate', write: true),
  const JwConsoleOperation('heart-stream-stop', '停止实时心率', 1,
      capability: 'heartRate', write: true),
  const JwConsoleOperation('spo2-permission', '查询血氧测量许可', 1,
      capability: 'bloodOxygen'),
  for (final pair in [
    ('hr', '单次心率'),
    ('spo2', '单次血氧'),
    ('temperature', '单次温度'),
    ('bp', '手动血压')
  ]) ...[
    JwConsoleOperation('manual-${pair.$1}-start', '开始${pair.$2}', 1,
        capability: 'manual-${pair.$1}',
        write: true,
        note: '命令提交 / 模式回包不等于传感器数值；血氧、温度无实时数值接口。'),
    JwConsoleOperation('manual-${pair.$1}-stop', '停止${pair.$2}', 1,
        capability: 'manual-${pair.$1}', write: true, note: '只停止本会话启动的测量。'),
  ],
  const JwConsoleOperation('wrist-read', '读取抬腕', 3,
      capability: 'turnOverWrist'),
  const JwConsoleOperation('wrist-set', '设置抬腕并读回', 3,
      capability: 'turnOverWrist', write: true, fields: [_enabled]),
  const JwConsoleOperation('heat-read', '读取热应激时间过滤', 3,
      capability: 'heatStressReminder'),
  const JwConsoleOperation('heat-set', '设置热应激时间过滤并读回', 3,
      capability: 'heatStressReminder',
      write: true,
      note: '关闭时间过滤表示全天允许；不代表关闭提醒。',
      fields: [
        JwConsoleField('enabled', '时间过滤', '0', {'0': '全天允许', '1': '按时段过滤'}),
        ..._timeFields
      ]),
  const JwConsoleOperation('longSit-read', '读取久坐提醒', 3,
      capability: 'longSit', note: '该固件查询可能暂时改变运行开关，仅手动单项读取。'),
  const JwConsoleOperation('longSit-set', '设置久坐提醒并读回', 3,
      capability: 'longSit',
      write: true,
      note: '关闭时保留未修改的休眠时分原字节；修改时间或开启时须输入合法时分。保留两个未知原始字节。',
      fields: [
        _enabled,
        ..._timeFields,
        JwConsoleField('interval', '间隔分钟（0–255）', '60')
      ]),
  const JwConsoleOperation('alarm-read', '读取闹钟整表', 3,
      capability: 'legacyAlarm', note: '最多 20 条；读取整表后增删改，冲突和不能往返的单次保留字段会阻止写入。'),
  const JwConsoleOperation('alarm-add', '新增闹钟', 3,
      capability: 'legacyAlarm', write: true, fields: _alarmFields),
  const JwConsoleOperation('alarm-modify', '修改闹钟', 3,
      capability: 'legacyAlarm',
      write: true,
      fields: [JwConsoleField('index', '表内下标（从 0 开始）', '0'), ..._alarmFields]),
  const JwConsoleOperation('alarm-delete', '删除闹钟', 3,
      capability: 'legacyAlarm',
      write: true,
      fields: [JwConsoleField('index', '表内下标（从 0 开始）', '0')]),
  const JwConsoleOperation('disturb-read', '读取勿扰诊断', 3, capability: 'disturb'),
  const JwConsoleOperation('highHr-read', '读取高心率提醒诊断', 3,
      capability: 'highHeartRateReminder'),
  const JwConsoleOperation('risk-notification', '通知提醒写入', 3,
      blocked: '风险写入锁定：可能改变配对状态。'),
  const JwConsoleOperation('risk-disturb', '勿扰写入', 3,
      blocked: '风险写入锁定：可能改变配对状态。'),
  const JwConsoleOperation('risk-highHr', '高心率提醒写入', 3,
      blocked: '风险写入锁定：当前固件写入不可安全验证。'),
  const JwConsoleOperation('sport-read', '读取实际支持的 UK 运动类型', 4,
      capability: 'exercise'),
  const JwConsoleOperation('sport-cache', '查看本会话运动类型缓存', 4,
      capability: 'exercise', note: '缓存不表示再次向设备查询。'),
  const JwConsoleOperation('sport-query', '查询当前运动状态', 4,
      capability: 'sportControl'),
  const JwConsoleOperation('sport-start', '开始运动', 4,
      capability: 'sportControl',
      write: true,
      fields: [JwConsoleField('type', '实际支持的 UK 类型代码（1–27）')]),
  for (final a in [('pause', '暂停'), ('resume', '恢复'), ('stop', '停止')])
    JwConsoleOperation('sport-${a.$1}', '${a.$2}本会话运动', 4,
        capability: 'sportControl', write: true),
  const JwConsoleOperation('profile', '提交资料与可选目标', 5,
      write: true,
      note: '仅 ACK / 部分提交证据，无资料独立读回或恢复声明。留空目标不提交。',
      fields: [
        JwConsoleField('gender', '性别', '0', {'0': '女', '1': '男'}),
        JwConsoleField('age', '年龄（0–127）'),
        JwConsoleField('height', '身高 cm（0<x<256，0.5 精度）'),
        JwConsoleField('weight', '体重 kg（0<x<512，0.5 精度）'),
        JwConsoleField('steps', '可选步数目标（1–4294967295）'),
        JwConsoleField('sleep', '可选睡眠分钟（1–65535）')
      ]),
  const JwConsoleOperation('photo-start', '进入设备拍照模式', 6,
      capability: 'camera', write: true, note: '仅设备模式命令；未实现手机相机。'),
  const JwConsoleOperation('photo-stop', '停止本会话拍照模式', 6,
      capability: 'camera', write: true),
  const JwConsoleOperation('find-start', '查找设备：开始 IAS 提醒', 6,
      capability: 'findDevice',
      write: true,
      note: '仅证明 IAS 写入，物理响铃 / 震动须观察设备。'),
  const JwConsoleOperation('find-stop', '停止本会话 IAS 提醒', 6,
      capability: 'findDevice', write: true),
  for (final item in <(String, int)>[
    ('setBloodSugarUnit', 0),
    ('setDrinkWaterReminder', 3),
    ('readDrinkWaterReminder', 3),
    ('setBloodSugarAutoMeasureConfig', 2),
    ('readBloodSugarAutoMeasureConfig', 2),
    ('setUricAcidAutoMeasureConfig', 2),
    ('readUricAcidAutoMeasureConfig', 2),
    ('setBloodFatAutoMeasureConfig', 2),
    ('readBloodFatAutoMeasureConfig', 2),
    ('setPressureAutoMeasureConfig', 2),
    ('readPressureAutoMeasureConfig', 2),
    ('readContinuousMonitoringSwitches', 2),
    ('checkHeartRateRealtimeStatus', 1),
    ('controlBloodSugarMeasurement', 1),
    ('controlECGMeasurement', 1),
    ('setPrivateBloodPressure', 1),
    ('setWeather', 6),
  ])
    JwConsoleOperation('unsupported-${item.$1}', item.$1, item.$2,
        blocked: '当前 V101 S200 T005/H001 合同不支持，无法执行。'),
];
JwConsoleOperation jwConsoleOperation(String id) =>
    jwConsoleOperations.firstWhere((o) => o.id == id);
