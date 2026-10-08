import 'package:flutter/material.dart';
import 'jw_test_console_catalog.dart';
import '../../services/jw/jw_configuration.dart';
import '../../services/jw/jw_models.dart';
import '../../services/jw/jw_remaining_models.dart';
import 'jw_test_console_controller.dart';

class JwConsoleOperationCard extends StatefulWidget {
  final JwConsoleOperation operation;
  final JwTestConsoleController controller;
  final Map<String, String> draft;
  const JwConsoleOperationCard(
      {super.key,
      required this.operation,
      required this.controller,
      required this.draft});
  @override
  State<JwConsoleOperationCard> createState() => _JwConsoleOperationCardState();
}

class _JwConsoleOperationCardState extends State<JwConsoleOperationCard> {
  final _inputs = <String, TextEditingController>{};
  @override
  void initState() {
    super.initState();
    for (final field in widget.operation.fields) {
      widget.draft.putIfAbsent(field.name, () => field.initial);
      _inputs[field.name] =
          TextEditingController(text: widget.draft[field.name]);
    }
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant JwConsoleOperationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hydrate();
  }

  void _hydrate() {
    final id = widget.operation.id, c = widget.controller;
    Object? source;
    if (id.startsWith('config-') && id.endsWith('-set')) {
      source = c.current[id.substring(0, id.length - 4)];
    }
    if (id == 'wrist-set') source = c.current['wrist'];
    if (id == 'heat-set') source = c.current['heat'];
    if (id == 'longSit-set') source = c.current['longSit'];
    if (id == 'alarm-modify') {
      final table = c.current['alarm'],
          index = int.tryParse(widget.draft['index'] ?? '');
      if (table is JwAlarmTable &&
          index != null &&
          index >= 0 &&
          index < table.records.length) {
        source = table.records[index];
      }
    }
    if (source == null || identical(c.formSources[id], source)) return;
    c.formSources[id] = source;
    final values = <String, String>{};
    String flag(bool? value) => value == true ? '1' : '0';
    if (source is JwConfigurationValue) {
      if (source.domain.isScalar) values['value'] = '${source.scalarValue}';
      if (source.domain.isMonitor) values['enabled'] = flag(source.enabled);
      if (source.bloodPressureDisplay != null) {
        values['display'] = flag(source.bloodPressureDisplay);
      }
      if (source.domain == JwConfigurationDomain.temperatureConfig) {
        values['display'] = flag(source.displayEnabled);
        values['compensate'] = flag(source.compensate);
        values['celsius'] = flag(source.celsius);
      }
    }
    if (source is JwTurnOverWristStatus) {
      values['enabled'] = flag(source.savedEnabled);
    }
    if (source is JwHeatStressReminderStatus) {
      values['enabled'] = flag(source.timeWindowEnabled);
      values['startHour'] = '${source.startMinutes ~/ 60}';
      values['startMinute'] = '${source.startMinutes % 60}';
      values['endHour'] = '${source.endMinutes ~/ 60}';
      values['endMinute'] = '${source.endMinutes % 60}';
    }
    if (source is JwLongSitSettings) {
      values['enabled'] = flag(source.enabled);
      values['startHour'] = '${source.startHour}';
      values['startMinute'] = '${source.startMinute}';
      values['endHour'] = '${source.endHour}';
      values['endMinute'] = '${source.endMinute}';
      values['interval'] = '${source.intervalMinutes}';
    }
    if (source is JwAlarmRecord) {
      values['date'] =
          '${source.year.toString().padLeft(4, '0')}-${source.month.toString().padLeft(2, '0')}-${source.day.toString().padLeft(2, '0')}';
      values['hour'] = '${source.hour}';
      values['minute'] = '${source.minute}';
      values['id'] = '${source.id}';
      values['repeat'] = '${source.repeatDays}';
    }
    widget.draft.addAll(values);
    for (final entry in values.entries) {
      _inputs[entry.key]?.text = entry.value;
    }
  }

  @override
  void dispose() {
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.operation,
        c = widget.controller,
        reason = c.disabledReason(op.id),
        result = c.results[op.id];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(op.label,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (op.note.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(op.note)),
                  for (final field in op.fields)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: field.options == null
                            ? TextField(
                                key: Key('jw-console-${op.id}-${field.name}'),
                                controller: _inputs[field.name],
                                enabled: c.active == null &&
                                    !c.state.operationInProgress,
                                keyboardType: field.name == 'date'
                                    ? TextInputType.datetime
                                    : const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                    labelText: field.label,
                                    border: const OutlineInputBorder()),
                                onChanged: (value) {
                                  widget.draft[field.name] = value;
                                  if (field.name == 'index') setState(_hydrate);
                                })
                            : InputDecorator(
                                decoration: InputDecoration(
                                    labelText: field.label,
                                    border: const OutlineInputBorder()),
                                child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                        key: Key(
                                            'jw-console-${op.id}-${field.name}'),
                                        isExpanded: true,
                                        value: widget.draft[field.name],
                                        items: [
                                          for (final entry
                                              in field.options!.entries)
                                            DropdownMenuItem(
                                                value: entry.key,
                                                child: Text(entry.value,
                                                    softWrap: true))
                                        ],
                                        onChanged: c.active != null ||
                                                c.state.operationInProgress
                                            ? null
                                            : (value) {
                                                if (value != null) {
                                                  setState(() =>
                                                      widget.draft[field.name] =
                                                          value);
                                                }
                                              })))),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      key: Key('jw-console-run-${op.id}'),
                      onPressed: reason == null
                          ? () => c.run(op.id, Map.of(widget.draft))
                          : null,
                      child: Text(c.active == op.id ? '执行中…' : '执行')),
                  Text(reason ?? '能力 / 合同允许执行',
                      key: Key('jw-console-reason-${op.id}')),
                  if (result != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(
                            '${result.success ? '结果' : '失败'}：${result.message}',
                            key: Key('jw-console-result-${op.id}'))),
                ])));
  }
}
