import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/localization.dart';

import '../../core/ui/components/layout/studio_layout.dart';

import '../../core/ui/components/navigation/studio_navigation.dart';
import '../../core/ui/showcase/component_gallery.dart';
import '../../features/home/video_home_screen.dart';
import '../../features/media/photo_library_screen.dart';
import '../../features/media/video_details_screen.dart';
import '../../features/media/photo_tools_screen.dart';
import '../../features/media/photo_preview_screen.dart';
import '../../features/media/trash_screen.dart';
import '../../features/editor/editing_hub_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/editor/export_screen.dart';
import '../../features/settings/settings_hub_screen.dart';
import '../../features/settings/help_screen.dart';
import '../../features/settings/support_screen.dart';
import '../../features/settings/audio_video_settings_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/onboarding_store.dart';

GoRouter createRouter() => GoRouter(
  initialLocation: '/videos',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/videos'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => StudioShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/videos',
              builder: (_, _) =>
                  const StudioTabScroll(index: 0, child: VideoHomeScreen()),
            ),
            GoRoute(
              path: '/videos/empty',
              builder: (_, _) => const StudioTabScroll(
                index: 0,
                child: VideoHomeScreen(empty: true),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/photos',
              builder: (_, _) =>
                  const StudioTabScroll(index: 1, child: PhotoLibraryScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/editor',
              builder: (_, _) =>
                  const StudioTabScroll(index: 2, child: EditingHubScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) =>
                  const StudioTabScroll(index: 3, child: SettingsHubScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings/audio-video',
      builder: (_, _) => const AudioVideoSettingsScreen(),
    ),
    GoRoute(path: '/recording/completed', redirect: (_, _) => '/videos'),
    GoRoute(
      path: '/editor/project/:id',
      builder: (_, state) => EditorScreen(
        key: ValueKey(state.pathParameters['id']),
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/trash', builder: (_, _) => const TrashScreen()),
    GoRoute(path: '/exports', builder: (_, _) => const ExportScreen()),
    GoRoute(
      path: '/help',
      builder: (_, state) => HelpScreen(
        key: ValueKey(state.uri.queryParameters['topic']),
        initialTopic: state.uri.queryParameters['topic'],
      ),
    ),
    GoRoute(path: '/support', builder: (_, _) => const SupportScreen()),
    if (kDebugMode)
      GoRoute(
        path: '/showcase/components',
        builder: (_, _) => const ComponentGallery(),
      ),
    GoRoute(
      path: '/introduction',
      builder: (context, _) => OnboardingScreen(
        store: const ReplayOnboardingStore(),
        initialPage: 0,
        replay: true,
        onCompleted: () => context.pop(),
      ),
    ),
    GoRoute(
      path: '/photo-preview/:id',
      builder: (_, state) => PhotoPreviewScreen(
        key: ValueKey(state.pathParameters['id']),
        uri: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/photo-tools/:id',
      builder: (_, state) => PhotoToolsScreen(
        key: ValueKey(state.pathParameters['id']),
        uri: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/media/:id',
      builder: (_, state) => VideoDetailsScreen(
        key: ValueKey(state.pathParameters['id']),
        id: state.pathParameters['id']!,
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.pageUnavailable)),
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/videos'),
        child: Text(context.l10n.returnToVideoStudio),
      ),
    ),
  ),
);
