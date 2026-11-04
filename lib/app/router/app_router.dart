import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/studio_shell.dart';
import '../../features/home/video_home_screen.dart';
import '../../features/media/photo_library_screen.dart';
import '../../features/media/video_details_screen.dart';
import '../../features/recording/recording_completed_screen.dart';
import '../../features/editor/editing_hub_screen.dart';
import '../../features/settings/settings_hub_screen.dart';
import '../../features/settings/audio_video_settings_screen.dart';

GoRouter createRouter() => GoRouter(
  initialLocation: '/videos',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/videos'),
    ShellRoute(
      builder: (context, state, child) =>
          StudioShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/videos', builder: (_, _) => const VideoHomeScreen()),
        GoRoute(
          path: '/videos/empty',
          builder: (_, _) => const VideoHomeScreen(empty: true),
        ),
        GoRoute(path: '/photos', builder: (_, _) => const PhotoLibraryScreen()),
        GoRoute(path: '/editor', builder: (_, _) => const EditingHubScreen()),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SettingsHubScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings/audio-video',
      builder: (_, _) => const AudioVideoSettingsScreen(),
    ),
    GoRoute(
      path: '/recording/completed',
      builder: (_, _) => const RecordingCompletedScreen(),
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
