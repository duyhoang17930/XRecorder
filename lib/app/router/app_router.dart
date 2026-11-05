import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/studio_tab_scroll.dart';

import '../../core/widgets/studio_shell.dart';
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
      builder: (_, state) => EditorScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(path: '/trash', builder: (_, _) => const TrashScreen()),
    GoRoute(path: '/exports', builder: (_, _) => const ExportScreen()),
    GoRoute(
      path: '/help',
      builder: (_, state) =>
          HelpScreen(initialTopic: state.uri.queryParameters['topic']),
    ),
    GoRoute(path: '/support', builder: (_, _) => const SupportScreen()),
    GoRoute(
      path: '/photo-preview/:id',
      builder: (_, state) =>
          PhotoPreviewScreen(uri: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/photo-tools/:id',
      builder: (_, state) => PhotoToolsScreen(uri: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/media/:id',
      builder: (_, state) =>
          VideoDetailsScreen(id: state.pathParameters['id']!),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page unavailable')),
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/videos'),
        child: const Text('Return to Video Studio'),
      ),
    ),
  ),
);
