import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/recording/recording_service.dart';
import '../../features/recording/recording_setup_sheet.dart';
import '../../l10n/localization.dart';
import '../ui/components/bottom_sheets/studio_sheet_launch.dart';
import 'studio_widgets.dart';

/// P2 presentation delegates capture to P1's public API unchanged.
Future<void> requestLibraryScreenshot(BuildContext context) async {
  final capture = CaptureScope.of(context);
  if (capture.busy) return;
  try {
    await capture.screenshot();
  } catch (error) {
    if (context.mounted) {
      showFailure(context, error, operation: UserOperation.screenshot);
    }
  }
}

Future<void> openQuickCreate(BuildContext host) => showStudioBottomSheet<void>(
  context: host,
  isScrollControlled: true,
  builder: (sheet) {
    final capture = CaptureScope.of(sheet);
    void dismiss() => Navigator.pop(sheet);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheet).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioSheetHeader(
              title: sheet.l10n.create,
              actions: [
                IconButton(
                  tooltip: sheet.l10n.close,
                  onPressed: dismiss,
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            StudioCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                minVerticalPadding: 16,
                leading: const StudioIconTile(icon: AppIcons.record),
                title: Text(sheet.l10n.recordScreen),
                subtitle: Text(
                  capture.busy
                      ? sheet.l10n.finishTheCurrentRecordingFirst
                      : sheet.l10n.recordingSettingsSummary,
                ),
                onTap: capture.busy
                    ? null
                    : () {
                        dismiss();
                        openRecordingSetup(host);
                      },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            StudioCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                minVerticalPadding: 16,
                leading: const StudioIconTile(icon: AppIcons.screenshot),
                title: Text(sheet.l10n.captureScreenshot),
                subtitle: Text(
                  capture.busy
                      ? sheet.l10n.finishTheCurrentRecordingFirst
                      : sheet.l10n.screenshotMinimizesTheAppAfterApproval3s,
                ),
                onTap: capture.busy
                    ? null
                    : () {
                        dismiss();
                        requestLibraryScreenshot(host);
                      },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(AppIcons.videoSettings),
              title: Text(sheet.l10n.recordingSettings),
              trailing: const Icon(AppIcons.chevronRight),
              onTap: () {
                dismiss();
                host.push('/settings/audio-video');
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.edit),
              title: Text(sheet.l10n.editingStudio),
              trailing: const Icon(AppIcons.chevronRight),
              onTap: () {
                dismiss();
                host.go('/editor');
              },
            ),
          ],
        ),
      ),
    );
  },
);

class StudioLibraryQuickActions extends StatelessWidget {
  const StudioLibraryQuickActions({super.key});
  @override
  Widget build(BuildContext context) => StudioBentoGrid(
    children: [
      QuickActionTile(
        title: context.l10n.captureScreenshot,
        icon: AppIcons.screenshot,
        onTap: CaptureScope.of(context).busy
            ? null
            : () => requestLibraryScreenshot(context),
      ),
      Builder(
        builder: (origin) => QuickActionTile(
          title: context.l10n.editorAllTools,
          icon: AppIcons.tools,
          onTap: () =>
              runStudioSheetLaunch(origin, () => openQuickCreate(context)),
        ),
      ),
    ],
  );
}
