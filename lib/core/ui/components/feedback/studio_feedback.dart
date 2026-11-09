import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_icons.dart';
import '../../../presentation/user_messages.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../cards/studio_cards.dart';

void showFailure(
  BuildContext context,
  Object? error, {
  required UserOperation operation,
}) {
  if (error is FlutterError) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        library: '3HRecorder UI',
        context: ErrorDescription('performing ${operation.name}'),
      ),
    );
  }
  final notice = UserMessages.failure(error, operation: operation);
  showNotice(
    context,
    notice.text,
    kind: notice.kind,
    helpTopic: notice.helpTopic,
  );
}

void showNotice(
  BuildContext context,
  String message, {
  NoticeKind kind = NoticeKind.info,
  String? helpTopic,
}) {
  if (!context.mounted) return;
  final c = context.studioColors;
  final (icon, accent) = switch (kind) {
    NoticeKind.success => (AppIcons.ready, c.cyan),
    NoticeKind.error => (AppIcons.error, c.warning),
    NoticeKind.warning => (AppIcons.warning, c.warning),
    NoticeKind.info => (AppIcons.info, c.primary),
    NoticeKind.loading => (AppIcons.processing, c.muted),
  };
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Color.alphaBlend(
          accent.withValues(alpha: .10),
          c.surface,
        ),
        duration: switch (kind) {
          NoticeKind.error => const Duration(seconds: 10),
          NoticeKind.warning => const Duration(seconds: 7),
          NoticeKind.loading => const Duration(seconds: 30),
          NoticeKind.success => const Duration(seconds: 3),
          NoticeKind.info => const Duration(seconds: 4),
        },
        showCloseIcon: true,
        closeIconColor: c.text,
        content: Row(
          children: [
            Icon(icon, color: accent, size: AppIconSize.large),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.message(message),
                style: AppTypography.body.copyWith(color: c.text),
              ),
            ),
          ],
        ),
        action: helpTopic == null
            ? null
            : SnackBarAction(
                label: context.l10n.help,
                textColor: c.primary,
                onPressed: () => context.push(
                  Uri(
                    path: '/help',
                    queryParameters: {'topic': helpTopic},
                  ).toString(),
                ),
              ),
      ),
    );
}

class StudioEmptyState extends StatelessWidget {
  const StudioEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });
  final String title;
  final String? description;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => StudioCard(
    padding: padding,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          StudioIconTile(
            icon: icon!,
            color: context.studioColors.muted,
            size: AppSize.emptyIcon,
            iconSize: AppIconSize.feature,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: context.studioColors.muted,
            ),
          ),
        ],
        if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
      ],
    ),
  );
}

class StudioLoadingState extends StatelessWidget {
  const StudioLoadingState({super.key, this.label = 'Loading your studio…'});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (context.reduceMotion)
            const Icon(AppIcons.processing)
          else
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: TextStyle(color: context.studioColors.muted)),
        ],
      ),
    ),
  );
}

/// Form and label carry status together; no endlessly pulsing recording dot.
class RecordingStatusIndicator extends StatelessWidget {
  const RecordingStatusIndicator({
    super.key,
    required this.label,
    this.active = false,
    this.icon,
    this.color,
  });
  final String label;
  final bool active;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon ?? (active ? AppIcons.record : AppIcons.ready),
        size: AppIconSize.small,
        color:
            color ??
            (active
                ? context.studioColors.recording
                : context.studioColors.cyan),
      ),
      const SizedBox(width: AppSpacing.xs),
      Flexible(
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color:
                color ??
                (active
                    ? context.studioColors.recording
                    : context.studioColors.muted),
          ),
        ),
      ),
    ],
  );
}

class StudioAnimatedSwitcher extends StatelessWidget {
  const StudioAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.standard,
  });
  final Widget child;
  final Duration duration;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: context.motion(duration),
    switchInCurve: AppMotion.enter,
    switchOutCurve: AppMotion.exit,
    child: child,
  );
}
