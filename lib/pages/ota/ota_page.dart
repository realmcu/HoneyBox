import 'package:flutter/material.dart';

/// OTA 升级 — reserved. The screen intentionally has no body yet; the update
/// flow will be implemented later.
class OtaPage extends StatelessWidget {
  const OtaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTA 升级')),
      body: const SizedBox.shrink(),
    );
  }
}
