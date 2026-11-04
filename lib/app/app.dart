import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/settings_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'app_configuration.dart';
import '../features/media/media_repository.dart';

class XRecorderApp extends StatefulWidget {
  const XRecorderApp({super.key, this.settings, this.mediaRepository});
  final SettingsController? settings;
  final CatalogRepository? mediaRepository;
  @override
  State<XRecorderApp> createState() => _XRecorderAppState();
}

class _XRecorderAppState extends State<XRecorderApp> {
  late final media = widget.mediaRepository ?? AndroidMediaRepository();
  late final settings = widget.settings ?? SettingsController();
  late final GoRouter router = createRouter();
  @override
  void dispose() {
    router.dispose();
    media.dispose();
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsScope(
    controller: settings,
    child: MediaScope(
      repository: media,
      child: MaterialApp.router(
        title: 'XRecorder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: AppConfiguration.themeMode,
        locale: AppConfiguration.locale,
        supportedLocales: AppConfiguration.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}
