import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/design_tokens.dart';

import '../features/settings/settings_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'app_configuration.dart';
import '../features/media/media_repository.dart';
import '../features/recording/recording_service.dart';

class XRecorderApp extends StatefulWidget {
  const XRecorderApp({super.key, this.settings, this.mediaRepository});
  final SettingsController? settings;
  final CatalogRepository? mediaRepository;
  @override
  State<XRecorderApp> createState() => _XRecorderAppState();
}

class _XRecorderAppState extends State<XRecorderApp> {
  late final media = widget.mediaRepository ?? AndroidMediaRepository();
  late final capture = CaptureController(
    AndroidRecordingService(),
    onSaved: media.refresh,
  );
  late final settings = widget.settings ?? SettingsController();
  late final GoRouter router = createRouter();
  @override
  void dispose() {
    router.dispose();
    capture.dispose();
    media.dispose();
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsScope(
    controller: settings,
    child: MediaScope(
      repository: media,
      child: CaptureScope(
        controller: capture,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: settings.themeModeListenable,
          builder: (context, mode, _) => MaterialApp.router(
            title: '3HRecorder',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            themeAnimationDuration:
                WidgetsBinding
                    .instance
                    .platformDispatcher
                    .accessibilityFeatures
                    .disableAnimations
                ? Duration.zero
                : AppMotion.standard,
            locale: AppConfiguration.locale,
            supportedLocales: AppConfiguration.supportedLocales,
            routerConfig: router,
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.overlayStyle(
                Theme.of(context).brightness,
                Theme.of(context).scaffoldBackgroundColor,
              ),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
}
