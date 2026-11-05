import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../constants/design_tokens.dart';
import '../constants/app_icons.dart';
import '../presentation/user_messages.dart';

export '../../app/theme/app_theme.dart' show AppTypography;
export '../constants/design_tokens.dart';
export '../constants/app_icons.dart';
export '../presentation/user_messages.dart';
export 'studio_fields.dart';
export 'studio_overlays.dart';

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
                message,
                style: AppTypography.body.copyWith(color: c.text),
              ),
            ),
          ],
        ),
        action: helpTopic == null
            ? null
            : SnackBarAction(
                label: 'Help',
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

class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.borderColor,
    this.radius = AppRadius.card,
    this.clipBehavior = Clip.antiAlias,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final Clip clipBehavior;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? context.studioColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: borderColor ?? context.studioColors.border,
        width: AppBorder.subtle,
      ),
    ),
    clipBehavior: clipBehavior,
    child: Padding(padding: padding, child: child),
  );
}

class StudioInset extends StatelessWidget {
  const StudioInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.color,
    this.radius = AppRadius.control,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? context.studioColors.background,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class StudioIconTile extends StatelessWidget {
  const StudioIconTile({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.size = AppSize.touchTarget,
    this.iconSize = AppIconSize.large,
    this.radius = AppRadius.icon,
  });
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size, iconSize, radius;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (color ?? context.studioColors.primary).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        color: color ?? context.studioColors.primary,
        size: iconSize,
      ),
    ),
  );
}

class StudioBadge extends StatelessWidget {
  const StudioBadge(this.label, {super.key, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.studioColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppTypography.badge.copyWith(color: ink)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class StudioSectionLabel extends StatelessWidget {
  const StudioSectionLabel(this.label, {super.key, this.padding});
  final String label;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding:
        padding ??
        const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: AppTypography.section.copyWith(
          color: context.studioColors.muted,
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

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = AppIcons.forward,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppIconSize.medium),
      label: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class RecordActionButton extends StatelessWidget {
  const RecordActionButton({
    super.key,
    required this.onPressed,
    this.label = 'Record screen',
  });
  final VoidCallback? onPressed;
  final String label;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: context.studioColors.recording,
      foregroundColor: context.studioColors.onRecording,
    ),
    icon: const Icon(AppIcons.record, size: AppIconSize.medium),
    label: Text(label, textAlign: TextAlign.center),
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

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: StudioCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: context.studioColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.bodyEmphasis)),
            ],
          ),
        ),
      ),
    ),
  );
}

class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.title,
    this.description,
    required this.icon,
    this.onTap,
    this.badge,
    this.accent,
  });
  final String title;
  final String? description;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final c = context.studioColors;
    final ink = onTap == null ? c.muted : accent ?? c.primary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: StudioCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.bentoMinimum),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StudioIconTile(icon: icon, color: ink),
                      const Spacer(),
                      if (onTap != null)
                        Icon(
                          AppIcons.open,
                          size: AppIconSize.small,
                          color: c.muted,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(title, style: AppTypography.bodyEmphasis),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description!,
                      style: AppTypography.bodySmall.copyWith(color: c.muted),
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    StudioBadge(badge!, color: ink),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bounded tool collections grow with text rather than clipping in fixed grid cells.
class StudioBentoGrid extends StatelessWidget {
  const StudioBentoGrid({
    super.key,
    required this.children,
    this.featuredFirst = false,
  });
  final List<Widget> children;
  final bool featuredFirst;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (children.isEmpty) return const SizedBox.shrink();
      final width = constraints.maxWidth;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final requestedColumns = width < AppBreakpoints.compact || scale > 1.5
          ? 1
          : width < AppBreakpoints.tablet
          ? 2
          : width < AppBreakpoints.wide
          ? 3
          : 4;
      final columns = requestedColumns.clamp(1, children.length);
      final unit = (width - AppSpacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(
              width:
                  featuredFirst &&
                      columns == 2 &&
                      (i == 0 ||
                          (i == children.length - 1 && children.length.isEven))
                  ? width
                  : unit,
              child: children[i],
            ),
        ],
      );
    },
  );
}

class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.disabledOptions = const {},
  });
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final Set<String> disabledOptions;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        children: options
            .map(
              (option) => Tooltip(
                message: disabledOptions.contains(option)
                    ? 'Not supported by this device or the selected mode'
                    : '',
                child: ChoiceChip(
                  label: Text(option),
                  selected: value == option,
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: disabledOptions.contains(option)
                        ? context.studioColors.disabled
                        : value == option
                        ? context.studioColors.primary
                        : context.studioColors.text,
                  ),
                  onSelected: disabledOptions.contains(option)
                      ? null
                      : (_) => onChanged(option),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: AppSpacing.md),
    ],
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow(
    this.title, {
    super.key,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.value,
    this.onChanged,
    this.iconColor,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    leading: StudioIconTile(icon: icon, color: iconColor),
    title: Text(title, style: AppTypography.bodyEmphasis),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: AppTypography.bodySmall.copyWith(
              color: context.studioColors.muted,
            ),
          ),
    trailing: value == null
        ? (onTap == null
              ? null
              : Icon(
                  AppIcons.chevronRight,
                  size: AppIconSize.medium,
                  color: context.studioColors.muted,
                ))
        : Switch(value: value!, onChanged: onChanged),
    onTap: onTap,
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
