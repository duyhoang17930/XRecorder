import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../features/recording/recording_setup_sheet.dart';
import '../constants/design_tokens.dart';

class StudioShell extends StatelessWidget {
  const StudioShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context) {
    final branch = navigationShell.currentIndex;
    final index = branch > 1 ? branch + 1 : branch;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: navigationShell,
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
              _nav('Video', Icons.videocam_outlined, 0, index),
              _nav('Photo', Icons.photo_camera_outlined, 1, index),
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
                          Icons.add,
                          color: AppColors.recordForeground,
                          size: AppIconSize.feature,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _nav('Edit', Icons.auto_fix_high, 3, index),
              _nav('Settings', Icons.settings_outlined, 4, index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(String label, IconData icon, int index, int selected) => Expanded(
    child: TextButton(
      onPressed: () => navigationShell.goBranch(index > 1 ? index - 1 : index),
      style: TextButton.styleFrom(
        foregroundColor: index == selected
            ? AppColors.primary
            : AppColors.navigationInactive,
        minimumSize: const Size(48, 64),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.large),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, maxLines: 1, style: AppTypography.navigation),
        ],
      ),
    ),
  );
}
