import 'dart:typed_data';

import '../errors.dart';
import 'address.dart';
import 'protocol.dart';
import 'status.dart';

class WSProtocolRegistry {
  WSProtocolRegistry(Iterable<WSProtocolEntry> entries,
      {Iterable<WSReport<Object?>> reports = const [],
      Set<int> blockedCommands = const {},
      Set<(int, int)> blockedKeys = const {}})
      : _blockedCommands = Set.unmodifiable(blockedCommands),
        _blockedKeys = Set.unmodifiable(blockedKeys) {
    for (final entry in entries) {
      entry.address.validate();
      if (_entries.containsKey(entry.address)) {
        throw StateError('duplicate ${entry.address}');
      }
      if ((_blockedCommands.contains(entry.address.cmd) ||
              _blockedKeys.contains((entry.address.cmd, entry.address.key))) &&
          entry.status != WSProtocolStatus.dropped &&
          entry.status != WSProtocolStatus.reserved) {
        throw StateError('blocked protocol range ${entry.address}');
      }
      _entries[entry.address] = entry;
    }
    for (final report in reports) {
      if (lookup(report.entry.address) != report.entry ||
          _reports.containsKey(report.entry.address) ||
          report.entry.address.direction != WSWireDirection.deviceToPhone) {
        throw StateError('invalid report registration');
      }
      _reports[report.entry.address] = report.decodeData;
    }
  }
  final Map<WSProtocolAddress, WSProtocolEntry> _entries = {};
  final Map<WSProtocolAddress, Object? Function(Uint8List)> _reports = {};
  final Set<int> _blockedCommands;
  final Set<(int, int)> _blockedKeys;
  List<WSProtocolEntry> get entries => List.unmodifiable(_entries.values);
  WSProtocolEntry? lookup(WSProtocolAddress address) => _entries[address];
  List<WSProtocolEntry> listByCommandKey(int cmd, int key) =>
      List.unmodifiable(_entries.values
          .where((e) => e.address.cmd == cmd && e.address.key == key));
  Object? decodeReport(WSProtocolAddress address, Uint8List data) =>
      _reports[address]?.call(data);
  bool hasReport(WSProtocolAddress address) => _reports.containsKey(address);

  void checkSend(WSProtocolAddress address, {bool raw = false}) {
    address.validate();
    if (address.direction != WSWireDirection.phoneToDevice) {
      throw ArgumentError('invalid send direction');
    }
    final status = lookup(address)?.status;
    if (_blockedCommands.contains(address.cmd) ||
        _blockedKeys.contains((address.cmd, address.key)) ||
        status == WSProtocolStatus.dropped ||
        status == WSProtocolStatus.reserved) {
      throw WSDroppedProtocolException('address is dropped/reserved: $address');
    }
    if (!raw && status != WSProtocolStatus.active) {
      throw ArgumentError('protocol is not implemented: $address');
    }
  }
}
