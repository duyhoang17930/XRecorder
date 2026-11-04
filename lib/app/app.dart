import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/settings_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class XRecorderApp extends StatefulWidget {
  const XRecorderApp({super.key});
  @override
  State<XRecorderApp> createState() => _XRecorderAppState();
}

class _XRecorderAppState extends State<XRecorderApp> {
  final settings = SettingsController();
  late final GoRouter router = createRouter();
  @override
  void dispose() {
    router.dispose();
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsScope(
    controller: settings,
    child: MaterialApp.router(
      title: 'XRecorder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    ),
  );
}
