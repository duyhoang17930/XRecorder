import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/theme/motion.dart';
import '../core/ui/theme/app_theme.dart';

import '../features/settings/settings_controller.dart';
import 'router/app_router.dart';
import 'app_configuration.dart';
import '../features/media/media_repository.dart';
import '../features/recording/recording_service.dart';
import '../core/presentation/thumbnail_cache.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/onboarding_store.dart';
import '../l10n/localization.dart';
import '../l10n/native_locale_sync.dart';

class XRecorderApp extends StatefulWidget {
  const XRecorderApp({
    super.key,
    this.settings,
    this.mediaRepository,
    this.startupFuture,
    this.onboardingStore,
  });
  final SettingsController? settings;
  final CatalogRepository? mediaRepository;
  final Future<OnboardingState>? startupFuture;
  final OnboardingStore? onboardingStore;
  @override
  State<XRecorderApp> createState() => _XRecorderAppState();
}

class _XRecorderAppState extends State<XRecorderApp>
    with WidgetsBindingObserver {
  final thumbnails = ThumbnailCache();
  StreamSubscription<void>? _thumbnailInvalidation;
  bool _onboardingCompleted = false;
  final _onboardingNavigator = GlobalKey<NavigatorState>(
    debugLabel: 'first-run-onboarding-navigator',
  );

  @override
  Future<bool> didPopRoute() async {
    final navigator = _onboardingNavigator.currentState;
    return navigator == null ? false : navigator.maybePop();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _thumbnailInvalidation = media.changes.listen((_) => thumbnails.clear());
  }

  @override
  void didHaveMemoryPressure() => thumbnails.clear();
  late final media = widget.mediaRepository ?? AndroidMediaRepository();
  late final capture = CaptureController(
    AndroidRecordingService(),
    onSaved: media.refresh,
  );
  late final settings = widget.settings ?? SettingsController();
  late final GoRouter router = createRouter();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _thumbnailInvalidation?.cancel();
    thumbnails.clear();
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
      thumbnails: thumbnails,
      child: CaptureScope(
        controller: capture,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: settings.themeModeListenable,
          builder: (context, mode, _) => ValueListenableBuilder<Locale?>(
            valueListenable: settings.appLocaleListenable,
            builder: (context, locale, _) => MaterialApp.router(
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
              locale: locale,
              supportedLocales: AppConfiguration.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              routerConfig: router,
              builder: (context, child) {
                final app = AnnotatedRegion<SystemUiOverlayStyle>(
                  value: AppTheme.overlayStyle(
                    Theme.of(context).brightness,
                    Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: NativeLocaleSync(child: child!),
                );
                final startup = widget.startupFuture;
                if (startup == null) return app;
                return FutureBuilder<OnboardingState>(
                  future: startup,
                  builder: (context, snapshot) {
                    final ready =
                        snapshot.connectionState == ConnectionState.done;
                    final onboardingStore = widget.onboardingStore;
                    final onboarding = snapshot.data;
                    final Widget destination;
                    if (!ready) {
                      destination = ColoredBox(
                        key: const ValueKey('startup-initializing'),
                        color:
                            MediaQuery.platformBrightnessOf(context) ==
                                Brightness.dark
                            ? const Color(0xFF0C1018)
                            : const Color(0xFFFAF9F6),
                        child: const SizedBox.expand(),
                      );
                    } else if (onboardingStore != null &&
                        onboarding != null &&
                        !onboarding.completed &&
                        !_onboardingCompleted) {
                      destination = Navigator(
                        key: _onboardingNavigator,
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (_) => OnboardingScreen(
                            key: const ValueKey('first-run-onboarding'),
                            store: onboardingStore,
                            initialPage: onboarding.page,
                            onCompleted: () {
                              if (mounted) {
                                setState(() => _onboardingCompleted = true);
                              }
                            },
                          ),
                        ),
                      );
                    } else {
                      destination = KeyedSubtree(
                        key: const ValueKey('startup-ready'),
                        child: app,
                      );
                    }
                    return destination;
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
