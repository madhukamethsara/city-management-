import 'package:flutter/material.dart';

import 'app.dart';
import 'data/demo_civic_repository.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(DemoCivicRepository());
  await controller.bootstrap();
  runApp(SmartSabhaApp(controller: controller));
}
