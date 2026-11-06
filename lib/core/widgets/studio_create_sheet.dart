import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';

import '../../features/recording/recording_setup_sheet.dart';
import '../../features/recording/recording_service.dart';
import '../../features/recording/capture_status_presentation.dart';
import '../../features/settings/settings_controller.dart';
import 'studio_widgets.dart';

Future<void> openStudioCreate(BuildContext context) =>
    showStudioBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .88,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudioSheetHeader(
                title: 'Create',
                actions: [
                  IconButton(
                    tooltip: 'Close create menu',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
              StudioQuickTools(
                hostContext: context,
                onDismiss: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );

class StudioRecordHero extends StatelessWidget {
  const StudioRecordHero({super.key});
  @override
  Widget build(BuildContext context) {
    final capture = CaptureScope.of(context);
    final c = context.studioColors;
    final settings = SettingsScope.of(context);
    final videoBusy = capture.busy && capture.session?.screenshot != true;
    final failed =
        capture.session?.screenshot != true &&
        (capture.error != null ||
            capture.session?.state == RecordingState.failed);
    final status = CaptureStatusPresentation.from(
      videoBusy || failed ? capture.session : null,
      error: failed ? capture.error : null,
    );
    return SizedBox(
      width: double.infinity,
      child: StudioCard(
        radius: AppRadius.feature,
        color: Color.alphaBlend(c.primary.withValues(alpha: .03), c.card),
        borderColor: c.border,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordingStatusIndicator(
              label: status.label,
              icon: status.icon,
              color: failed
                  ? c.warning
                  : videoBusy &&
                        ![
                          RecordingState.recording,
                          RecordingState.paused,
                        ].contains(capture.session?.state)
                  ? c.primary
                  : null,
              active: videoBusy,
            ),
            if (!videoBusy) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Screen recorder',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${settings.resolution} · ${settings.fps} FPS · ${settings.audio}',
                style: TextStyle(color: c.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              RecordActionButton(
                onPressed: capture.busy
                    ? null
                    : () => openRecordingSetup(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StudioQuickTools extends StatelessWidget {
  const StudioQuickTools({
    super.key,
    this.compact = false,
    this.hostContext,
    this.onDismiss,
  });
  final bool compact;
  final BuildContext? hostContext;
  final VoidCallback? onDismiss;
  @override
  Widget build(BuildContext context) {
    final target = hostContext ?? context;
    final capture = CaptureScope.of(context);
    void setup() {
      onDismiss?.call();
      openRecordingSetup(target);
    }

    void edit() {
      onDismiss?.call();
      target.go('/editor');
    }

    final screenshot = BentoCard(
      title: 'Screenshot',
      description: 'Minimizes after approval · 3s delay',
      icon: AppIcons.screenshot,
      accent: context.studioColors.cyan,
      badge: capture.busy ? 'Session active' : null,
      onTap: capture.busy
          ? null
          : () async {
              onDismiss?.call();
              try {
                await capture.screenshot();
              } catch (error) {
                if (target.mounted) {
                  showFailure(
                    target,
                    error,
                    operation: UserOperation.screenshot,
                  );
                }
              }
            },
    );
    final facecam = BentoCard(
      title: 'Facecam',
      description: 'Set up before recording',
      icon: AppIcons.facecam,
      onTap: setup,
    );
    final countdown = BentoCard(
      title: 'Countdown',
      description: 'Delay before recording',
      icon: AppIcons.countdown,
      onTap: setup,
    );
    final editor = BentoCard(
      title: 'Editing tools',
      description: 'Video & photo',
      icon: AppIcons.edit,
      onTap: edit,
      accent: context.studioColors.cyan,
    );
    return StudioBentoGrid(
      featuredFirst: !compact,
      children: compact
          ? [
              QuickActionTile(
                title: 'Screenshot',
                icon: AppIcons.screenshot,
                onTap: screenshot.onTap,
              ),
              QuickActionTile(
                title: 'All tools',
                icon: AppIcons.tools,
                onTap: () => openStudioCreate(context),
              ),
            ]
          : [
              BentoCard(
                title: 'Screen recording',
                description: 'Video, audio & facecam',
                icon: AppIcons.video,
                onTap: setup,
              ),
              screenshot,
              facecam,
              const BentoCard(
                title: 'Recording region',
                icon: AppIcons.region,
                badge: 'Unavailable',
              ),
              countdown,
              const BentoCard(
                title: 'Livestream',
                description: 'Not connected',
                icon: AppIcons.livestream,
                badge: 'Unavailable',
              ),
              const BentoCard(
                title: 'AI subtitles',
                description: 'Not connected',
                icon: AppIcons.captions,
                badge: 'Unavailable',
              ),
              editor,
            ],
    );
  }
}
