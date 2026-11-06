import 'dart:async';

import 'package:flutter/material.dart';

import 'jw_demo_controller.dart';
import 'jw_measure_hub_page.dart';

void openJwMeasureHub(BuildContext context, JWDemoController controller) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JWMeasureHubPage(controller: controller),
      ),
    ),
  );
}
