import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/auth_config.dart';
import 'data/auth/supabase_auth_repository.dart';
import 'data/demo_civic_repository.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AuthConfig.fromEnvironment();
  final controller = AppController(
    DemoCivicRepository(),
    auth: config.useSupabase ? SupabaseAuthRepository(config) : null,
  );
  unawaited(controller.bootstrap());
  runApp(SmartSabhaApp(controller: controller));
}
