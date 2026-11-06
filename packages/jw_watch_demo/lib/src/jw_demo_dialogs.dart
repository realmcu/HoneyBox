import 'package:flutter/material.dart';

import 'jw_settings_app_theme.dart';

/// Demo 通用弹窗 / BottomSheet，对齐 App：
/// - `SelectTimeBottomSheet`
/// - `SinglePickerBottomSheet`
/// - `CommonMessageDialog`

final class JwDemoTimeRange {
  const JwDemoTimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
}

abstract final class JwDemoDialogs {
  /// 起止时间 BottomSheet（开始/结束 Tab + 时分双列滚轮）。
  static Future<JwDemoTimeRange?> showSelectTime(
    BuildContext context, {
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    int minHour = 0,
    int maxHour = 23,
    String cancelText = '取消',
    String confirmText = '确定',
  }) {
    return showModalBottomSheet<JwDemoTimeRange>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SelectTimeSheet(
        startHour: startHour.clamp(minHour, maxHour),
        startMinute: startMinute.clamp(0, 59),
        endHour: endHour.clamp(minHour, maxHour),
        endMinute: endMinute.clamp(0, 59),
        minHour: minHour,
        maxHour: maxHour,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
  }

  /// 单列滚轮选择 BottomSheet（提醒间隔等）。
  static Future<T?> showSinglePicker<T>(
    BuildContext context, {
    required String title,
    required List<T> values,
    required String Function(T value) labelOf,
    T? initial,
    String? dataTips,
    String cancelText = '取消',
    String confirmText = '确定',
  }) {
    assert(values.isNotEmpty);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SinglePickerSheet<T>(
        title: title,
        values: values,
        labelOf: labelOf,
        initial: initial ?? values.first,
        dataTips: dataTips,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
  }

  /// 通用 Message 弹窗（取消 / 确认）。
  static Future<bool?> showMessage(
    BuildContext context, {
    String? title,
    String? detail,
    String negativeText = '取消',
    String positiveText = '确定',
    bool hideNegative = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => _MessageDialog(
        title: title,
        detail: detail,
        negativeText: negativeText,
        positiveText: positiveText,
        hideNegative: hideNegative,
      ),
    );
  }
}

class _SheetChrome extends StatelessWidget {
  const _SheetChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(JwSettingsAppTheme.buttonRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(JwSettingsAppTheme.buttonRadius),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
  });

  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: _SheetActionButton(
              label: cancelText,
              background: JwSettingsAppTheme.negativeButton,
              foreground: JwSettingsAppTheme.title,
              onPressed: onCancel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SheetActionButton(
              label: confirmText,
              background: JwSettingsAppTheme.positiveButton,
              foreground: JwSettingsAppTheme.positiveButtonText,
              onPressed: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单列滚轮；单位浮在选中行右侧（对齐 App 40dp 值宽 + 3dp 间距）。
class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    super.key,
    required this.values,
    required this.initialIndex,
    required this.onChanged,
    this.suffix,
  });

  final List<String> values;
  final int initialIndex;
  final ValueChanged<int> onChanged;
  final String? suffix;

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  static const _itemExtent = 40.0;
  static const _valueWidth = 40.0;
  late final FixedExtentScrollController _controller;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex.clamp(0, widget.values.length - 1);
    _controller = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: _itemExtent,
          physics: const FixedExtentScrollPhysics(),
          perspective: 0.0001,
          diameterRatio: 2.0,
          offAxisFraction: 0,
          onSelectedItemChanged: (index) {
            if (_selected == index) return;
            setState(() => _selected = index);
            widget.onChanged(index);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.values.length,
            builder: (context, index) {
              final selected = index == _selected;
              return Center(
                child: SizedBox(
                  width: _valueWidth,
                  child: Text(
                    widget.values[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: selected ? 20 : 16,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? JwSettingsAppTheme.title
                          : JwSettingsAppTheme.muted,
                      height: 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.suffix != null)
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: _valueWidth),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Text(
                    widget.suffix!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: JwSettingsAppTheme.title,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SelectTimeSheet extends StatefulWidget {
  const _SelectTimeSheet({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.minHour,
    required this.maxHour,
    required this.cancelText,
    required this.confirmText,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int minHour;
  final int maxHour;
  final String cancelText;
  final String confirmText;

  @override
  State<_SelectTimeSheet> createState() => _SelectTimeSheetState();
}

class _SelectTimeSheetState extends State<_SelectTimeSheet> {
  late int _startHour = widget.startHour;
  late int _startMinute = widget.startMinute;
  late int _endHour = widget.endHour;
  late int _endMinute = widget.endMinute;
  var _editingStart = true;

  late final List<String> _hours = [
    for (var h = widget.minHour; h <= widget.maxHour; h++)
      h.toString().padLeft(2, '0'),
  ];
  late final List<String> _minutes = [
    for (var m = 0; m <= 59; m++) m.toString().padLeft(2, '0'),
  ];

  String _fmt(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Widget _timeChip(
    String text, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? JwSettingsAppTheme.sheetTimeTipSelectedBg
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 17,
              height: 1.2,
              color: selected
                  ? JwSettingsAppTheme.sheetTimeTipSelectedText
                  : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeColumns({
    required Key hourKey,
    required Key minKey,
    required int hour,
    required int minute,
    required ValueChanged<int> onHour,
    required ValueChanged<int> onMinute,
  }) {
    return Row(
      children: [
        Expanded(
          child: _WheelColumn(
            key: hourKey,
            values: _hours,
            initialIndex: (hour - widget.minHour).clamp(0, _hours.length - 1),
            suffix: '时',
            onChanged: onHour,
          ),
        ),
        Expanded(
          child: _WheelColumn(
            key: minKey,
            values: _minutes,
            initialIndex: minute.clamp(0, 59),
            suffix: '分',
            onChanged: onMinute,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timeChip(
                _fmt(_startHour, _startMinute),
                selected: _editingStart,
                onTap: () {
                  if (_editingStart) return;
                  setState(() => _editingStart = true);
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: JwSettingsAppTheme.muted,
                ),
              ),
              _timeChip(
                _fmt(_endHour, _endMinute),
                selected: !_editingStart,
                onTap: () {
                  if (!_editingStart) return;
                  setState(() => _editingStart = false);
                },
              ),
            ],
          ),
          SizedBox(
            height: 170,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
              child: Stack(
                children: [
                  // 与 App 一致：开始/结束两套时分滚轮常驻，切换 Tab 只改可见性，避免重建卡顿。
                  IndexedStack(
                    index: _editingStart ? 0 : 1,
                    sizing: StackFit.expand,
                    children: [
                      _timeColumns(
                        hourKey: const ValueKey('start-hour'),
                        minKey: const ValueKey('start-min'),
                        hour: _startHour,
                        minute: _startMinute,
                        onHour: (index) {
                          final hour = widget.minHour + index;
                          if (hour == _startHour) return;
                          setState(() => _startHour = hour);
                        },
                        onMinute: (index) {
                          if (index == _startMinute) return;
                          setState(() => _startMinute = index);
                        },
                      ),
                      _timeColumns(
                        hourKey: const ValueKey('end-hour'),
                        minKey: const ValueKey('end-min'),
                        hour: _endHour,
                        minute: _endMinute,
                        onHour: (index) {
                          final hour = widget.minHour + index;
                          if (hour == _endHour) return;
                          setState(() => _endHour = hour);
                        },
                        onMinute: (index) {
                          if (index == _endMinute) return;
                          setState(() => _endMinute = index);
                        },
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        height: 40,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: JwSettingsAppTheme.divider),
                            bottom:
                                BorderSide(color: JwSettingsAppTheme.divider),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _SheetActions(
            cancelText: widget.cancelText,
            confirmText: widget.confirmText,
            onCancel: () => Navigator.pop(context),
            onConfirm: () => Navigator.pop(
              context,
              JwDemoTimeRange(
                startHour: _startHour,
                startMinute: _startMinute,
                endHour: _endHour,
                endMinute: _endMinute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinglePickerSheet<T> extends StatefulWidget {
  const _SinglePickerSheet({
    required this.title,
    required this.values,
    required this.labelOf,
    required this.initial,
    required this.dataTips,
    required this.cancelText,
    required this.confirmText,
  });

  final String title;
  final List<T> values;
  final String Function(T value) labelOf;
  final T initial;
  final String? dataTips;
  final String cancelText;
  final String confirmText;

  @override
  State<_SinglePickerSheet<T>> createState() => _SinglePickerSheetState<T>();
}

class _SinglePickerSheetState<T> extends State<_SinglePickerSheet<T>> {
  late int _index = widget.values.indexOf(widget.initial).clamp(
        0,
        widget.values.length - 1,
      );
  late final List<String> _labels =
      [for (final v in widget.values) widget.labelOf(v)];

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: JwSettingsAppTheme.title,
              ),
            ),
          ),
          SizedBox(
            height: 170,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Stack(
                children: [
                  _WheelColumn(
                    values: _labels,
                    initialIndex: _index,
                    suffix: widget.dataTips,
                    onChanged: (index) {
                      if (index == _index) return;
                      _index = index;
                    },
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        height: 40,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: JwSettingsAppTheme.divider),
                            bottom:
                                BorderSide(color: JwSettingsAppTheme.divider),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _SheetActions(
            cancelText: widget.cancelText,
            confirmText: widget.confirmText,
            onCancel: () => Navigator.pop(context),
            onConfirm: () => Navigator.pop(context, widget.values[_index]),
          ),
        ],
      ),
    );
  }
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({
    required this.title,
    required this.detail,
    required this.negativeText,
    required this.positiveText,
    required this.hideNegative,
  });

  final String? title;
  final String? detail;
  final String negativeText;
  final String positiveText;
  final bool hideNegative;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * (340 / 375);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal:
            (MediaQuery.sizeOf(context).width - width).clamp(16, 48) / 2,
      ),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null && title!.isNotEmpty)
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: JwSettingsAppTheme.title,
                  ),
                ),
              if (detail != null && detail!.isNotEmpty) ...[
                if (title != null && title!.isNotEmpty)
                  const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Text(
                      detail!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: JwSettingsAppTheme.subtitle,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              Row(
                children: [
                  if (!hideNegative) ...[
                    Expanded(
                      child: _SheetActionButton(
                        label: negativeText,
                        background: JwSettingsAppTheme.negativeButton,
                        foreground: JwSettingsAppTheme.title,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _SheetActionButton(
                      label: positiveText,
                      background: JwSettingsAppTheme.positiveButton,
                      foreground: JwSettingsAppTheme.positiveButtonText,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
