import 'package:flutter/material.dart';
import 'package:watch_lab_ui/watch_lab_ui.dart';

void main() {
  runApp(
    const MaterialApp(
      home: TransportDiagnosticsPage(
        profileMode: TransportProfileMode.selectable,
      ),
    ),
  );
}
