import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/recording/recording_setup_sheet.dart';
import '../constants/design_tokens.dart';

class StudioShell extends StatelessWidget {
  const StudioShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/photos')
        ? 1
        : location.startsWith('/editor')
        ? 3
        : location.startsWith('/settings')
        ? 4
        : 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _nav(
                context,
                'Video',
                Icons.videocam_outlined,
                0,
                index,
                '/videos',
              ),
              _nav(
                context,
                'Photo',
                Icons.photo_camera_outlined,
                1,
                index,
                '/photos',
              ),
              Expanded(
                child: Center(
                  heightFactor: 1,
                  child: Semantics(
                    label: 'Record',
                    button: true,
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: FloatingActionButton(
                        tooltip: 'Record',
                        heroTag: 'record',
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: AppColors.background,
                            width: 4,
                          ),
                        ),
                        backgroundColor: AppColors.primary,
                        onPressed: () => openRecordingSetup(context),
                        child: const Icon(
                          Icons.radio_button_checked,
                          color: Color(0xFF681E00),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _nav(context, 'Edit', Icons.auto_fix_high, 3, index, '/editor'),
              _nav(
                context,
                'Settings',
                Icons.settings_outlined,
                4,
                index,
                '/settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(
    BuildContext context,
    String label,
    IconData icon,
    int index,
    int selected,
    String route,
  ) => Expanded(
    child: TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(
        foregroundColor: index == selected
            ? AppColors.primary
            : const Color(0xFFDFC0B6),
        minimumSize: const Size(48, 64),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 25),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
