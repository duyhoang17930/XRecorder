import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
              builder: (_, _) => const VideoHomeScreen(),
            ),
            GoRoute(
              path: '/videos/empty',
              builder: (_, _) => const VideoHomeScreen(empty: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/photos',
              builder: (_, _) => const PhotoLibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/editor',
              builder: (_, _) => const EditingHubScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsHubScreen(),
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
