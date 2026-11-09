import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_app_bp_touch_chart.dart';
import 'jw_app_chart_models.dart';
import 'jw_app_glu_touch_chart.dart';
import 'jw_app_hr_touch_chart.dart';
import 'jw_app_hrv_touch_chart.dart';
import 'jw_app_pressure_touch_chart.dart';
import 'jw_app_sleep_touch_chart.dart';
import 'jw_app_spo2_touch_chart.dart';
import 'jw_app_sport_day_chart.dart';
import 'jw_app_step_touch_chart.dart';
import 'jw_app_temp_touch_chart.dart';
import 'jw_data_catalog.dart';
import 'jw_data_units.dart';
import 'jw_demo_controller.dart';
import 'jw_health_app_theme.dart';
import 'jw_health_date_nav_bar.dart';

/// App `Watch*DataFragment` 风格详情：亮色顶区图表 + 长按 buoy + 下方统计。
class JwDataDetailPage extends StatefulWidget {
  const JwDataDetailPage({
    super.key,
    required this.controller,
    required this.item,
    this.initialDay,
  });

  final JWDemoController controller;
  final JwDataTypeItem item;
  final DateTime? initialDay;

  @override
  State<JwDataDetailPage> createState() => _JwDataDetailPageState();
}

class _JwDataDetailPageState extends State<JwDataDetailPage> {
  late DateTime _day = jwDataDayStart(widget.initialDay ?? DateTime.now());
  var _loading = false;
  Object? _error;
  List<Object> _records = const [];

  // —— 图表模型缓存（按类型仅一组有效）——
  List<JwAppStepSlot> _stepSlots = const [];
  int _stepMax = 1;

  List<JwAppHrHourBucket> _hrHours = const [];
  int _hrAxisMax = 120;
  int _hrAxisMin = 40;
  double _hrAvg = 0;

  List<JwAppSleepSegment> _sleepSegments = const [];

  List<JwAppBpHourBucket> _bpHours = const [];
  int _bpAxisMax = 180;
  int _bpAxisMin = 30;

  List<JwAppSpo2HourBucket> _spo2Hours = const [];
  int _spo2AxisMax = 100;
  int _spo2AxisMin = 85;

  List<JwAppTempSlot> _tempSlots = const [];
  double _tempAxisMax = 50;
  double _tempAxisMin = 0;
  double _tempAvg = 0;

  List<JwAppHrvHourBucket> _hrvHours = const [];

  List<JwAppPressureSlot> _pressureSlots = const [];
  int _pressureAxisMax = 100;
  int _pressureAxisMin = 0;
  int _pressureAvg = 0;

  List<JwAppGluHourBucket> _gluHours = const [];
  double _gluAxisMax = 16.5;
  double _gluAxisMin = 0;
  double _gluAvg = 0;

  List<JwAppSportHourBar> _sportBars = const [];

  // —— 选中浮标（可空；与图表一一对应）——
  JwAppStepTouchSelection? _stepSel;
  JwAppHrTouchSelection? _hrSel;
  JwAppSleepTouchSelection? _sleepSel;
  JwAppBpTouchSelection? _bpSel;
  JwAppSpo2TouchSelection? _spo2Sel;
  JwAppTempTouchSelection? _tempSel;
  JwAppHrvTouchSelection? _hrvSel;
  JwAppPressureTouchSelection? _pressureSel;
  JwAppGluTouchSelection? _gluSel;
  JwAppSportDayTouchSelection? _sportSel;

  JWWatchSession? get _session => widget.controller.session;

  bool get _canGoNext {
    final today = jwDataDayStart(DateTime.now());
    return _day.isBefore(today);
  }

  bool get _hasAnySelection =>
      _stepSel != null ||
      _hrSel != null ||
      _sleepSel != null ||
      _bpSel != null ||
      _spo2Sel != null ||
      _tempSel != null ||
      _hrvSel != null ||
      _pressureSel != null ||
      _gluSel != null ||
      _sportSel != null;

  void _clearAllSelections() {
    _stepSel = null;
    _hrSel = null;
    _sleepSel = null;
    _bpSel = null;
    _spo2Sel = null;
    _tempSel = null;
    _hrvSel = null;
    _pressureSel = null;
    _gluSel = null;
    _sportSel = null;
  }

  void _clearChartModelCaches() {
    _stepSlots = const [];
    _stepMax = 1;
    _hrHours = const [];
    _hrAxisMax = 120;
    _hrAxisMin = 40;
    _hrAvg = 0;
    _sleepSegments = const [];
    _bpHours = const [];
    _bpAxisMax = 180;
    _bpAxisMin = 30;
    _spo2Hours = const [];
    _spo2AxisMax = 100;
    _spo2AxisMin = 85;
    _tempSlots = const [];
    _tempAxisMax = 50;
    _tempAxisMin = 0;
    _tempAvg = 0;
    _hrvHours = const [];
    _pressureSlots = const [];
    _pressureAxisMax = 100;
    _pressureAxisMin = 0;
    _pressureAvg = 0;
    _gluHours = const [];
    _gluAxisMax = 16.5;
    _gluAxisMin = 0;
    _gluAvg = 0;
    _sportBars = const [];
  }

  void _scheduleSelection(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  void _onStepSelection(JwAppStepTouchSelection? sel) {
    if (!mounted || identical(_stepSel, sel)) return;
    if (_stepSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_stepSel, sel)) return;
      if (_stepSel == null && sel == null) return;
      setState(() => _stepSel = sel);
    });
  }

  void _onHrSelection(JwAppHrTouchSelection? sel) {
    if (!mounted || identical(_hrSel, sel)) return;
    if (_hrSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_hrSel, sel)) return;
      if (_hrSel == null && sel == null) return;
      setState(() => _hrSel = sel);
    });
  }

  void _onSleepSelection(JwAppSleepTouchSelection? sel) {
    if (!mounted || identical(_sleepSel, sel)) return;
    if (_sleepSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_sleepSel, sel)) return;
      if (_sleepSel == null && sel == null) return;
      setState(() => _sleepSel = sel);
    });
  }

  void _onBpSelection(JwAppBpTouchSelection? sel) {
    if (!mounted || identical(_bpSel, sel)) return;
    if (_bpSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_bpSel, sel)) return;
      if (_bpSel == null && sel == null) return;
      setState(() => _bpSel = sel);
    });
  }

  void _onSpo2Selection(JwAppSpo2TouchSelection? sel) {
    if (!mounted || identical(_spo2Sel, sel)) return;
    if (_spo2Sel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_spo2Sel, sel)) return;
      if (_spo2Sel == null && sel == null) return;
      setState(() => _spo2Sel = sel);
    });
  }

  void _onTempSelection(JwAppTempTouchSelection? sel) {
    if (!mounted || identical(_tempSel, sel)) return;
    if (_tempSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_tempSel, sel)) return;
      if (_tempSel == null && sel == null) return;
      setState(() => _tempSel = sel);
    });
  }

  void _onHrvSelection(JwAppHrvTouchSelection? sel) {
    if (!mounted || identical(_hrvSel, sel)) return;
    if (_hrvSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_hrvSel, sel)) return;
      if (_hrvSel == null && sel == null) return;
      setState(() => _hrvSel = sel);
    });
  }

  void _onPressureSelection(JwAppPressureTouchSelection? sel) {
    if (!mounted || identical(_pressureSel, sel)) return;
    if (_pressureSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_pressureSel, sel)) return;
      if (_pressureSel == null && sel == null) return;
      setState(() => _pressureSel = sel);
    });
  }

  void _onGluSelection(JwAppGluTouchSelection? sel) {
    if (!mounted || identical(_gluSel, sel)) return;
    if (_gluSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_gluSel, sel)) return;
      if (_gluSel == null && sel == null) return;
      setState(() => _gluSel = sel);
    });
  }

  void _onSportSelection(JwAppSportDayTouchSelection? sel) {
    if (!mounted || identical(_sportSel, sel)) return;
    if (_sportSel == null && sel == null) return;
    _scheduleSelection(() {
      if (!mounted || identical(_sportSel, sel)) return;
      if (_sportSel == null && sel == null) return;
      setState(() => _sportSel = sel);
    });
  }

  void _rebuildChartModels(List<Object> rows) {
    _clearChartModelCaches();
    switch (widget.item.id) {
      case JwDataTypeId.activity:
        _stepSlots = jwAppBuildStepSlots(rows, _day);
        _stepMax = jwAppStepMaxAxis(_stepSlots);
        break;
      case JwDataTypeId.heartRate:
        _hrHours = jwAppBuildHrHours(rows, _day);
        final axis = jwAppHrAxis(_hrHours);
        _hrAxisMax = axis.max;
        _hrAxisMin = axis.min;
        _hrAvg = axis.avg;
        break;
      case JwDataTypeId.sleep:
        _sleepSegments = jwAppBuildSleepSegments(rows);
        break;
      case JwDataTypeId.bloodPressure:
        _bpHours = jwAppBuildBpHours(rows, _day);
        final bp = jwAppBpAxis(_bpHours);
        _bpAxisMax = bp.max;
        _bpAxisMin = bp.min;
        break;
      case JwDataTypeId.bloodOxygen:
        _spo2Hours = jwAppBuildSpo2Hours(rows, _day);
        final spo2 = jwAppSpo2Axis(_spo2Hours);
        _spo2AxisMax = spo2.max;
        _spo2AxisMin = spo2.min;
        break;
      case JwDataTypeId.temperature:
        _tempSlots = jwAppBuildTempSlots(rows, _day);
        final t = jwAppTempAxis(_tempSlots);
        _tempAxisMax = t.max;
        _tempAxisMin = t.min;
        _tempAvg = t.avg;
        break;
      case JwDataTypeId.hrv:
        _hrvHours = jwAppBuildHrvHours(rows, _day);
        break;
      case JwDataTypeId.pressure:
        _pressureSlots = jwAppBuildPressureSlots(rows, _day);
        final p = jwAppPressureAxis(_pressureSlots);
        _pressureAxisMax = p.axisMax;
        _pressureAxisMin = 0;
        _pressureAvg = p.avg;
        break;
      case JwDataTypeId.bloodSugar:
        _gluHours = jwAppBuildGluHours(rows, _day);
        final g = jwAppGluAxis(_gluHours);
        _gluAxisMax = g.max;
        _gluAxisMin = g.min;
        _gluAvg = g.avg;
        break;
      case JwDataTypeId.sport:
        _sportBars = jwAppBuildSportHours(rows, _day);
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _clearAllSelections();
    });
    try {
      final session = _session;
      final scope = session?.historyScope;
      if (session == null || scope == null) {
        if (!mounted) return;
        setState(() {
          _records = const [];
          _rebuildChartModels(const []);
          _loading = false;
        });
        return;
      }
      final rows = await jwDataQueryDay(
        store: session.historyStore,
        scope: scope,
        id: widget.item.id,
        day: _day,
      );
      if (!mounted) return;
      setState(() {
        _records = rows;
        _rebuildChartModels(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _records = const [];
        _rebuildChartModels(const []);
        _loading = false;
      });
    }
  }

  void _shiftDay(int delta) {
    final next = jwDataDayStart(_day.add(Duration(days: delta)));
    final today = jwDataDayStart(DateTime.now());
    if (next.isAfter(today)) return;
    setState(() => _day = next);
    unawaited(_load());
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: jwDataDayStart(DateTime.now()),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = jwDataDayStart(picked));
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    const topH = JwHealthAppTheme.topPanelHeight;

    return Scaffold(
      backgroundColor: JwHealthAppTheme.pageBg,
      appBar: AppBar(
        backgroundColor: JwHealthAppTheme.toolbarBg,
        foregroundColor: JwHealthAppTheme.toolbarFg,
        elevation: 0,
        title: Text(
          widget.item.title,
          style: const TextStyle(
            color: JwHealthAppTheme.toolbarFg,
            fontSize: 17,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                describeJWDemoError(_error!),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: topH,
                  child: ColoredBox(
                    color: JwHealthAppTheme.topBg,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: JwHealthAppTheme.dateBarHeight,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              if (!_hasAnySelection)
                                JwHealthDateNavBar(
                                  day: _day,
                                  canGoNext: _canGoNext,
                                  onPrev: () => _shiftDay(-1),
                                  onNext: () => _shiftDay(1),
                                  onPick: _pickDay,
                                  onToday: () {
                                    setState(
                                      () => _day =
                                          jwDataDayStart(DateTime.now()),
                                    );
                                    unawaited(_load());
                                  },
                                  prevKey: const Key(
                                    'jw.demo.data.detail.prev_day',
                                  ),
                                  nextKey: const Key(
                                    'jw.demo.data.detail.next_day',
                                  ),
                                  pickKey: const Key(
                                    'jw.demo.data.detail.pick_day',
                                  ),
                                ),
                              if (_stepSel != null)
                                _StepBuoy(
                                  selection: _stepSel!,
                                  parentWidth: width,
                                ),
                              if (_hrSel != null)
                                _HrBuoy(
                                  selection: _hrSel!,
                                  parentWidth: width,
                                ),
                              if (_sleepSel != null)
                                _SleepBuoy(
                                  selection: _sleepSel!,
                                  parentWidth: width,
                                ),
                              if (_bpSel != null)
                                _BpBuoy(
                                  selection: _bpSel!,
                                  parentWidth: width,
                                ),
                              if (_spo2Sel != null)
                                _Spo2Buoy(
                                  selection: _spo2Sel!,
                                  parentWidth: width,
                                ),
                              if (_tempSel != null)
                                _TempBuoy(
                                  selection: _tempSel!,
                                  parentWidth: width,
                                ),
                              if (_hrvSel != null)
                                _HrvBuoy(
                                  selection: _hrvSel!,
                                  parentWidth: width,
                                ),
                              if (_pressureSel != null)
                                _PressureBuoy(
                                  selection: _pressureSel!,
                                  parentWidth: width,
                                ),
                              if (_gluSel != null)
                                _GluBuoy(
                                  selection: _gluSel!,
                                  parentWidth: width,
                                ),
                              if (_sportSel != null)
                                _SportBuoy(
                                  selection: _sportSel!,
                                  parentWidth: width,
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: JwHealthAppTheme.dateBarHeight,
                          left: 17,
                          right: 17,
                          bottom: JwHealthAppTheme.chartBottomInset,
                          child: _buildChart(),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildStatsSection(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '共 ${_records.length} 条记录',
                    style: const TextStyle(
                      fontSize: 13,
                      color: JwHealthAppTheme.infoUnit,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final record in _records)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: ListTile(
                        title: Text(
                          jwDataLatestSummary(record),
                          style: const TextStyle(
                            color: JwHealthAppTheme.infoTitle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          jwDataRecordDetailLine(record),
                          style: const TextStyle(
                            fontSize: 12,
                            color: JwHealthAppTheme.infoUnit,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    switch (widget.item.id) {
      case JwDataTypeId.activity:
        return JwAppStepTouchChart(
          key: ValueKey('step-$_day'),
          slots: _stepSlots,
          maxSteps: _stepMax,
          onSelection: _onStepSelection,
        );
      case JwDataTypeId.heartRate:
        return JwAppHrTouchChart(
          key: ValueKey('hr-$_day'),
          hours: _hrHours,
          axisMax: _hrAxisMax,
          axisMin: _hrAxisMin,
          averageRate: _hrAvg,
          onSelection: _onHrSelection,
        );
      case JwDataTypeId.sleep:
        return JwAppSleepTouchChart(
          key: ValueKey('sleep-$_day'),
          segments: _sleepSegments,
          onSelection: _onSleepSelection,
        );
      case JwDataTypeId.bloodPressure:
        return JwAppBpTouchChart(
          key: ValueKey('bp-$_day'),
          hours: _bpHours,
          axisMax: _bpAxisMax,
          axisMin: _bpAxisMin,
          onSelection: _onBpSelection,
        );
      case JwDataTypeId.bloodOxygen:
        return JwAppSpo2TouchChart(
          key: ValueKey('spo2-$_day'),
          hours: _spo2Hours,
          axisMax: _spo2AxisMax,
          axisMin: _spo2AxisMin,
          onSelection: _onSpo2Selection,
        );
      case JwDataTypeId.temperature:
        return JwAppTempTouchChart(
          key: ValueKey('temp-$_day'),
          slots: _tempSlots,
          axisMax: _tempAxisMax,
          axisMin: _tempAxisMin,
          averageRate: _tempAvg,
          onSelection: _onTempSelection,
        );
      case JwDataTypeId.hrv:
        return JwAppHrvTouchChart(
          key: ValueKey('hrv-$_day'),
          hours: _hrvHours,
          onSelection: _onHrvSelection,
        );
      case JwDataTypeId.pressure:
        return JwAppPressureTouchChart(
          key: ValueKey('pressure-$_day'),
          slots: _pressureSlots,
          axisMax: _pressureAxisMax,
          axisMin: _pressureAxisMin,
          averageRate: _pressureAvg,
          onSelection: _onPressureSelection,
        );
      case JwDataTypeId.bloodSugar:
        return JwAppGluTouchChart(
          key: ValueKey('glu-$_day'),
          hours: _gluHours,
          axisMax: _gluAxisMax,
          axisMin: _gluAxisMin,
          averageRate: _gluAvg,
          onSelection: _onGluSelection,
        );
      case JwDataTypeId.sport:
        return JwAppSportDayChart(
          key: ValueKey('sport-$_day'),
          bars: _sportBars,
          onSelection: _onSportSelection,
        );
    }
  }

  Widget _buildStatsSection() {
    switch (widget.item.id) {
      case JwDataTypeId.activity:
        return _buildStepStats();
      case JwDataTypeId.heartRate:
        return _buildHrStats();
      case JwDataTypeId.sleep:
        return _buildSleepStats();
      case JwDataTypeId.bloodPressure:
        return _buildBpStats();
      case JwDataTypeId.bloodOxygen:
        return _buildSpo2Stats();
      case JwDataTypeId.temperature:
        return _buildTempStats();
      case JwDataTypeId.hrv:
        return _buildHrvStats();
      case JwDataTypeId.pressure:
        return _buildPressureStats();
      case JwDataTypeId.bloodSugar:
        return _buildGluStats();
      case JwDataTypeId.sport:
        return _buildSportStats();
    }
  }

  Widget _buildStepStats() {
    var steps = 0;
    var kcal = 0;
    var distance = 0;
    for (final row in _records) {
      if (row is! JWActivity) continue;
      steps += row.steps;
      kcal += jwDataCalToKcal(row.energy).round();
      distance += row.distance;
    }
    const target = 10000;
    final percent = steps <= 0 ? 0 : ((steps / target) * 100).round();
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$percent%',
                title: '目标完成',
                unit: '今日目标',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$steps',
                title: '总步数',
                unit: '步',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: jwDataFormatKm(distance),
                title: '距离',
                unit: '公里',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$kcal',
                title: '热量',
                unit: '千卡',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '半小时段 ${_stepSlots.where((e) => e.steps > 0).length} / 48',
          style: const TextStyle(
            fontSize: 12,
            color: JwHealthAppTheme.infoUnit,
          ),
        ),
      ],
    );
  }

  Widget _buildHrStats() {
    var max = 0;
    var min = 999;
    for (final h in _hrHours) {
      for (final r in h.rates) {
        if (r <= 0) continue;
        if (r > max) max = r;
        if (r < min) min = r;
      }
    }
    if (min == 999) min = 0;
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: _hrAvg <= 0 ? '--' : '${_hrAvg.round()}',
                title: '平均心率',
                unit: 'bpm',
                valueColor: JwHealthAppTheme.hrValueEsp,
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: max <= 0 ? '--' : '$max',
                title: '最高',
                unit: 'bpm',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: min <= 0 ? '--' : '$min',
                title: '最低',
                unit: 'bpm',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSleepStats() {
    final s = jwDataSummarizeSleep(_records);
    if (s.totalMinutes <= 0 && _sleepSegments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: jwDataFormatDuration(s.lightMinutes * 60),
                title: '浅睡',
                unit: '时长',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: jwDataFormatDuration(s.deepMinutes * 60),
                title: '深睡',
                unit: '时长',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: jwDataFormatDuration(s.awakeMinutes * 60),
                title: '清醒',
                unit: '时长',
              ),
            ),
            if (s.remMinutes > 0) ...[
              Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
              Expanded(
                child: _StatBlock(
                  value: jwDataFormatDuration(s.remMinutes * 60),
                  title: '快速眼动',
                  unit: '时长',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBpStats() {
    final samples = _records.whereType<JWBloodPressure>().toList();
    if (samples.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    var sumSys = 0;
    var sumDia = 0;
    var sysMax = 0;
    var sysMin = 999;
    var diaMax = 0;
    var diaMin = 999;
    for (final r in samples) {
      sumSys += r.systolic;
      sumDia += r.diastolic;
      sysMax = math.max(sysMax, r.systolic);
      sysMin = math.min(sysMin, r.systolic);
      diaMax = math.max(diaMax, r.diastolic);
      diaMin = math.min(diaMin, r.diastolic);
    }
    final n = samples.length;
    final avgSys = (sumSys / n).round();
    final avgDia = (sumDia / n).round();
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$avgSys/$avgDia',
                title: '平均血压',
                unit: 'mmHg',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$sysMax',
                title: '收缩压最高',
                unit: 'mmHg',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$sysMin',
                title: '收缩压最低',
                unit: 'mmHg',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$diaMax',
                title: '舒张压最高',
                unit: 'mmHg',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$diaMin',
                title: '舒张压最低',
                unit: 'mmHg',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpo2Stats() {
    final vals = <int>[
      for (final r in _records)
        if (r is JWBloodOxygen && r.value > 0) r.value,
    ];
    if (vals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    final sum = vals.fold<int>(0, (a, b) => a + b);
    final avg = (sum / vals.length).round();
    final max = vals.reduce(math.max);
    final min = vals.reduce(math.min);
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$avg',
                title: '平均血氧',
                unit: '%',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$max',
                title: '最高',
                unit: '%',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$min',
                title: '最低',
                unit: '%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTempStats() {
    final temps = <double>[
      for (final r in _records)
        if (r is JWTemperature && r.skinTemperature > 0) r.skinTemperature,
    ];
    if (temps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    final sum = temps.fold<double>(0, (a, b) => a + b);
    final avg = sum / temps.length;
    final max = temps.reduce(math.max);
    final min = temps.reduce(math.min);
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: avg.toStringAsFixed(1),
                title: '平均体温',
                unit: '℃',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: max.toStringAsFixed(1),
                title: '最高',
                unit: '℃',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: min.toStringAsFixed(1),
                title: '最低',
                unit: '℃',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHrvStats() {
    final sdnn = <int>[
      for (final r in _records)
        if (r is JWHrv && r.sdnn > 0) r.sdnn,
    ];
    if (sdnn.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    final sum = sdnn.fold<int>(0, (a, b) => a + b);
    final avg = (sum / sdnn.length).round();
    final max = sdnn.reduce(math.max);
    final min = sdnn.reduce(math.min);
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$avg',
                title: '平均 SDNN',
                unit: 'ms',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$max',
                title: '最高',
                unit: 'ms',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$min',
                title: '最低',
                unit: 'ms',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPressureStats() {
    final vals = <int>[
      for (final r in _records)
        if (r is JWPressure && r.value > 0) r.value,
    ];
    if (vals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    final sum = vals.fold<int>(0, (a, b) => a + b);
    final avg = (sum / vals.length).round();
    final max = vals.reduce(math.max);
    final min = vals.reduce(math.min);
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$avg',
                title: '平均压力',
                unit: '',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$max',
                title: '最高',
                unit: '',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '$min',
                title: '最低',
                unit: '',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGluStats() {
    final mmol = <double>[
      for (final r in _records)
        if (r is JWBloodGlucose && r.value > 0) r.value / 10.0,
    ];
    if (mmol.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    final sum = mmol.fold<double>(0, (a, b) => a + b);
    final avg = sum / mmol.length;
    final max = mmol.reduce(math.max);
    final min = mmol.reduce(math.min);
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: avg.toStringAsFixed(1),
                title: '平均血糖',
                unit: 'mmol/L',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: max.toStringAsFixed(1),
                title: '最高',
                unit: 'mmol/L',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: min.toStringAsFixed(1),
                title: '最低',
                unit: 'mmol/L',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSportStats() {
    final sports = _records.whereType<JWSport>().toList();
    if (sports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '当天暂无数据',
          textAlign: TextAlign.center,
          style: TextStyle(color: JwHealthAppTheme.infoUnit),
        ),
      );
    }
    var seconds = 0;
    var steps = 0;
    for (final r in sports) {
      seconds += r.duration;
      steps += r.steps;
    }
    return _WhiteStatsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: jwDataFormatDuration(seconds),
                title: '运动时长',
                unit: '合计',
              ),
            ),
            Container(width: 1, height: 64, color: const Color(0xFFE6E6E6)),
            Expanded(
              child: _StatBlock(
                value: '${sports.length}',
                title: '运动次数',
                unit: '次',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '$steps',
                title: '合计步数',
                unit: '步',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _sleepStageLabelForAppType(int appType) => switch (appType) {
      0 => '深睡',
      1 => '浅睡',
      2 || 3 => '眼动',
      4 => '清醒',
      _ => '阶段',
    };

class _StepBuoy extends StatelessWidget {
  const _StepBuoy({required this.selection, required this.parentWidth});
  final JwAppStepTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.stepBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(label: '步数', value: '${selection.steps}', unit: '步'),
          const SizedBox(width: 12),
          _BuoyMetric(label: '热量', value: '${selection.kcal}', unit: '千卡'),
        ],
      ),
    );
  }
}

class _HrBuoy extends StatelessWidget {
  const _HrBuoy({required this.selection, required this.parentWidth});
  final JwAppHrTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.hrBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '平均',
            value: selection.avgHr > 0 ? '${selection.avgHr}' : '--',
            unit: 'bpm',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最高',
            value: selection.maxHr > 0 ? '${selection.maxHr}' : '--',
            unit: 'bpm',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最低',
            value: selection.minHr > 0 ? '${selection.minHr}' : '--',
            unit: 'bpm',
          ),
        ],
      ),
    );
  }
}

class _SleepBuoy extends StatelessWidget {
  const _SleepBuoy({required this.selection, required this.parentWidth});
  final JwAppSleepTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    final stage = _sleepStageLabelForAppType(selection.appType);
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.sleepBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: stage,
            value: '${selection.minutes}',
            unit: '分钟',
          ),
        ],
      ),
    );
  }
}

class _BpBuoy extends StatelessWidget {
  const _BpBuoy({required this.selection, required this.parentWidth});
  final JwAppBpTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.bpBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '收缩',
            value: selection.high > 0 ? '${selection.high}' : '--',
            unit: 'mmHg',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '舒张',
            value: selection.low > 0 ? '${selection.low}' : '--',
            unit: 'mmHg',
          ),
        ],
      ),
    );
  }
}

class _Spo2Buoy extends StatelessWidget {
  const _Spo2Buoy({required this.selection, required this.parentWidth});
  final JwAppSpo2TouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.spo2Buoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '最高',
            value: selection.max > 0 ? '${selection.max}' : '--',
            unit: '%',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最低',
            value: selection.min > 0 ? '${selection.min}' : '--',
            unit: '%',
          ),
        ],
      ),
    );
  }
}

class _TempBuoy extends StatelessWidget {
  const _TempBuoy({required this.selection, required this.parentWidth});
  final JwAppTempTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.tempBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '平均',
            value: selection.avg > 0 ? selection.avg.toStringAsFixed(1) : '--',
            unit: '℃',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最高',
            value: selection.max > 0 ? selection.max.toStringAsFixed(1) : '--',
            unit: '℃',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最低',
            value: selection.min > 0 ? selection.min.toStringAsFixed(1) : '--',
            unit: '℃',
          ),
        ],
      ),
    );
  }
}

class _HrvBuoy extends StatelessWidget {
  const _HrvBuoy({required this.selection, required this.parentWidth});
  final JwAppHrvTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.hrvBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '最高',
            value: selection.maxHrv > 0 ? '${selection.maxHrv}' : '--',
            unit: 'ms',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最低',
            value: selection.minHrv > 0 ? '${selection.minHrv}' : '--',
            unit: 'ms',
          ),
        ],
      ),
    );
  }
}

class _PressureBuoy extends StatelessWidget {
  const _PressureBuoy({required this.selection, required this.parentWidth});
  final JwAppPressureTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.pressureBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '平均',
            value: selection.avg > 0 ? '${selection.avg}' : '--',
            unit: '',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最高',
            value: selection.max > 0 ? '${selection.max}' : '--',
            unit: '',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最低',
            value: selection.min > 0 ? '${selection.min}' : '--',
            unit: '',
          ),
        ],
      ),
    );
  }
}

class _GluBuoy extends StatelessWidget {
  const _GluBuoy({required this.selection, required this.parentWidth});
  final JwAppGluTouchSelection selection;
  final double parentWidth;

  String _fmt(double v) => v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.gluBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '平均',
            value: selection.avg > 0 ? _fmt(selection.avg) : '--',
            unit: 'mmol/L',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最高',
            value: selection.max > 0 ? _fmt(selection.max) : '--',
            unit: 'mmol/L',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '最低',
            value: selection.min > 0 ? _fmt(selection.min) : '--',
            unit: 'mmol/L',
          ),
        ],
      ),
    );
  }
}

class _SportBuoy extends StatelessWidget {
  const _SportBuoy({required this.selection, required this.parentWidth});
  final JwAppSportDayTouchSelection selection;
  final double parentWidth;

  @override
  Widget build(BuildContext context) {
    return _BuoyPositioner(
      anchorX: selection.anchorX + 17,
      parentWidth: parentWidth,
      color: JwHealthAppTheme.sportBuoy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BuoyTimeRange(begin: _hm(selection.begin), end: _hm(selection.end)),
          const _BuoyDivider(),
          _BuoyMetric(
            label: '时长',
            value: '${selection.minutes}',
            unit: '分钟',
          ),
          const SizedBox(width: 12),
          _BuoyMetric(
            label: '场次',
            value: '${selection.sessions}',
            unit: '次',
          ),
        ],
      ),
    );
  }
}

/// App buoy 内容壳：高度贴日期条，宽度随内容（不要拉满屏宽）。
class _BuoyShell extends StatelessWidget {
  const _BuoyShell({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: JwHealthAppTheme.dateBarHeight - 12,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5.3),
      ),
      child: child,
    );
  }
}

class _BuoyTimeRange extends StatelessWidget {
  const _BuoyTimeRange({required this.begin, required this.end});
  final String begin;
  final String end;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          begin,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.0,
          ),
        ),
        Container(width: 1, height: 4, color: Colors.white),
        Text(
          end,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _BuoyDivider extends StatelessWidget {
  const _BuoyDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.only(left: 15),
      color: Colors.white,
    );
  }
}

class _BuoyMetric extends StatelessWidget {
  const _BuoyMetric({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              height: 1.0,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 浮标定位：内容宽度自适应；优先相对 [anchorX] 居中，贴边时整体平移保证完整可见。
/// 下方指示线始终落在长按锚点 X，可与气泡错位。
class _BuoyPositioner extends StatelessWidget {
  const _BuoyPositioner({
    required this.anchorX,
    required this.parentWidth,
    required this.color,
    required this.child,
  });

  final double anchorX;
  final double parentWidth;
  final Color color;
  final Widget child;

  static const _edgePad = 19.0;
  static const _topPad = 12.0;
  static const _indicatorH = 8.0;

  @override
  Widget build(BuildContext context) {
    final shell = _BuoyShell(color: color, child: child);
    return SizedBox(
      width: parentWidth,
      height: JwHealthAppTheme.dateBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: _topPad,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomSingleChildLayout(
              delegate: _BuoyLayoutDelegate(
                anchorX: anchorX,
                parentWidth: parentWidth,
                edgePad: _edgePad,
              ),
              child: shell,
            ),
          ),
          // pop 下方指示线：钉在锚点 X，不随气泡左右夹紧而漂移。
          Positioned(
            left: anchorX.clamp(0.0, parentWidth) - 0.5,
            top: JwHealthAppTheme.dateBarHeight - _indicatorH,
            width: 1,
            height: _indicatorH,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    );
  }
}

class _BuoyLayoutDelegate extends SingleChildLayoutDelegate {
  _BuoyLayoutDelegate({
    required this.anchorX,
    required this.parentWidth,
    required this.edgePad,
  });

  final double anchorX;
  final double parentWidth;
  final double edgePad;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = math.max(0.0, parentWidth - edgePad * 2);
    return BoxConstraints(
      minWidth: 0,
      maxWidth: maxW,
      minHeight: 0,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 对齐 App updateBuoysPosition：先按锚点居中，再夹到可见区。
    final minLeft = edgePad;
    final maxLeft = math.max(minLeft, parentWidth - edgePad - childSize.width);
    var left = anchorX - childSize.width / 2;
    if (left < minLeft) left = minLeft;
    if (left > maxLeft) left = maxLeft;
    return Offset(left, 0);
  }

  @override
  bool shouldRelayout(covariant _BuoyLayoutDelegate oldDelegate) {
    return oldDelegate.anchorX != anchorX ||
        oldDelegate.parentWidth != parentWidth ||
        oldDelegate.edgePad != edgePad;
  }
}

class _WhiteStatsCard extends StatelessWidget {
  const _WhiteStatsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: JwHealthAppTheme.infoItem,
      padding: const EdgeInsets.fromLTRB(19, 26, 19, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.title,
    required this.unit,
    this.valueColor = JwHealthAppTheme.infoTitle,
  });

  final String value;
  final String title;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 23.6,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.4,
            color: JwHealthAppTheme.infoTitleLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 10.6,
            color: JwHealthAppTheme.infoUnit,
          ),
        ),
      ],
    );
  }
}
