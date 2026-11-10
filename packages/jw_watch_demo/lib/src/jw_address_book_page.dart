import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jw_watch_sdk/jw_watch_sdk.dart';

import 'jw_demo_controller.dart';
import 'jw_settings_api_sheet.dart';
import 'jw_settings_app_theme.dart';

/// 对齐 App `AddressBookActivity` 下发路径；联系人用内置模拟数据。
class JwAddressBookPage extends StatefulWidget {
  const JwAddressBookPage({super.key, required this.controller});

  final JWDemoController controller;

  @override
  State<JwAddressBookPage> createState() => _JwAddressBookPageState();
}

class _JwAddressBookPageState extends State<JwAddressBookPage> {
  static final _mockContacts = <_MockContact>[
    const _MockContact('陈晨', '13800001111', selected: true),
    const _MockContact('林薇', '13900002222', selected: true),
    const _MockContact('王磊', '13700003333', selected: true),
    const _MockContact('赵敏', '13600004444'),
    const _MockContact('刘洋', '13500005555'),
    const _MockContact('周婷', '13400006666'),
  ];

  late List<_MockContact> _contacts;
  bool _syncing = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _contacts = _mockContacts.map((c) => c.copy()).toList();
  }

  List<JWAddressBookEntry> _selectedEntries() => [
        for (final row in _contacts)
          if (row.selected)
            JWAddressBookEntry(name: row.name, phone: row.phone),
      ];

  Future<void> _syncToWatch() async {
    final entries = _selectedEntries();
    if (entries.length > kJwMaxAddressBookEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('最多选择 $kJwMaxAddressBookEntries 位联系人'),
        ),
      );
      return;
    }
    setState(() {
      _syncing = true;
      _progress = entries.isEmpty ? null : 0;
    });
    try {
      await widget.controller.setAddressBook(entries);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entries.isEmpty ? '已清空手表通讯录' : '已同步 ${entries.length} 位联系人',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _clearOnWatch() async {
    setState(() {
      _syncing = true;
      _progress = null;
    });
    try {
      await widget.controller.setAddressBook(const []);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空手表通讯录')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeJWDemoError(e))),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _toggle(int index, bool? value) {
    if (_syncing || value == null) return;
    setState(() => _contacts[index] = _contacts[index].copyWith(selected: value));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedEntries().length;
    return Scaffold(
      backgroundColor: JwSettingsAppTheme.background,
      appBar: AppBar(
        backgroundColor: JwSettingsAppTheme.toolbar,
        elevation: 0,
        title: JwSettingsApiTitle(
          title: '通讯录',
          apiCode: JwSettingsApiExamples.addressBook,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '演示数据 · 勾选后同步到手表（最多 $kJwMaxAddressBookEntries 条）',
              style: JwSettingsAppTheme.itemSubTitle,
            ),
          ),
          if (_syncing && _progress != null)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _contacts[index];
                final disabled = _syncing ||
                    (!row.selected &&
                        selected >= kJwMaxAddressBookEntries);
                return CheckboxListTile(
                  value: row.selected,
                  onChanged: disabled ? null : (v) => _toggle(index, v),
                  title: Text(row.name, style: JwSettingsAppTheme.itemTitle),
                  subtitle:
                      Text(row.phone, style: JwSettingsAppTheme.itemSubTitle),
                  secondary: CircleAvatar(
                    backgroundColor: JwSettingsAppTheme.accent.withValues(alpha: 0.15),
                    child: Text(
                      row.name.isNotEmpty ? row.name[0] : '?',
                      style: TextStyle(color: JwSettingsAppTheme.accent),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _syncing ? null : () => unawaited(_syncToWatch()),
                  child: Text(_syncing ? '同步中…' : '同步到手表（$selected）'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _syncing ? null : () => unawaited(_clearOnWatch()),
                  child: const Text('仅清空手表通讯录'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _MockContact {
  const _MockContact(this.name, this.phone, {this.selected = false});

  final String name;
  final String phone;
  final bool selected;

  _MockContact copyWith({bool? selected}) => _MockContact(
        name,
        phone,
        selected: selected ?? this.selected,
      );

  _MockContact copy() => _MockContact(name, phone, selected: selected);
}
