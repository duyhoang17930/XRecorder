import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';

import '../../features/recording/recording_setup_sheet.dart';
import '../../features/recording/recording_service.dart';
import '../../features/recording/capture_status_presentation.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/recording/region_capture_page.dart';
import '../../features/recording/livestream_page.dart';
import '../domain/repositories.dart';
import '../../l10n/localization.dart';
import '../constants/app_icons.dart';
import '../presentation/user_messages.dart';
import '../ui/components/bottom_sheets/studio_bottom_sheet.dart';
import '../ui/components/buttons/studio_buttons.dart';
import '../ui/components/cards/studio_cards.dart';
import '../ui/components/feedback/studio_feedback.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/radius.dart';
import '../ui/theme/spacing.dart';

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
              label: context.message(status.label),
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
                context.l10n.captureRecorderTitle,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${context.message(settings.resolution)} · ${settings.fps} FPS · ${context.message(settings.audio)}',
                style: TextStyle(color: c.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              RecordActionButton(
                label: context.l10n.recordScreen,
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
      description: context.l10n.screenshotDelaySummary(
        context.displayValue(
          SettingsScope.of(context).screenshotDelayDuration.inSeconds,
        ),
      ),
      icon: AppIcons.screenshot,
      accent: context.studioColors.cyan,
      badge: capture.busy ? 'Session active' : null,
      onTap: capture.busy
          ? null
          : () async {
              onDismiss?.call();
              try {
                await capture.screenshot(
                  delay: SettingsScope.of(context).screenshotDelayDuration,
                );
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
              BentoCard(
                title: context.l10n.regionCapture,
                icon: AppIcons.region,
                onTap:
                    capture.busy || capture.service is! RegionRecordingService
                    ? null
                    : () {
                        onDismiss?.call();
                        openRegionCapture(target);
                      },
              ),
              countdown,
              BentoCard(
                title: context.message('Livestream'),
                description: 'RTMP / RTMPS',
                icon: AppIcons.livestream,
                badge: capture.service is LivestreamRecordingService
                    ? null
                    : 'Unavailable',
                onTap: capture.service is! LivestreamRecordingService
                    ? null
                    : () {
                        onDismiss?.call();
                        openLivestream(target);
                      },
              ),
              BentoCard(
                title: context.l10n.offlineAutomaticSubtitles,
                description: context.l10n.editingStudio,
                icon: AppIcons.captions,
                onTap: edit,
              ),
              editor,
            ],
    );
  }
}
