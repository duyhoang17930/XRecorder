import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../constants/design_tokens.dart';

export '../../app/theme/app_theme.dart' show AppTypography;
export 'studio_fields.dart';
export 'studio_overlays.dart';

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void unsupported(BuildContext context, String feature) => showNotice(
  context,
  '$feature is not available in this UI baseline. No media was changed.',
);

class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.card,
    this.borderColor,
    this.radius = AppRadius.card,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final double radius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: clipBehavior,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class StudioInset extends StatelessWidget {
  const StudioInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.color = AppColors.background,
    this.radius = AppRadius.control,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class StudioIconTile extends StatelessWidget {
  const StudioIconTile({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.elevated,
    this.size = 36,
    this.iconSize = AppIconSize.medium,
    this.radius = AppRadius.icon,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    ),
  );
}

class StudioBadge extends StatelessWidget {
  const StudioBadge(this.label, {super.key, this.color = AppColors.cyan});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(label, style: AppTypography.badge.copyWith(color: color)),
  );
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
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
        const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
    child: Text(
      label,
      style: AppTypography.section.copyWith(color: AppColors.primary),
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
          Icon(icon, color: AppColors.muted, size: AppIconSize.feature),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.bodyEmphasis,
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: AppTypography.mutedCaption,
          ),
        ],
        if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
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

class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

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
              (option) => ChoiceChip(
                label: Text(option),
                selected: value == option,
                labelStyle: AppTypography.bodySmall.copyWith(
                  color: value == option
                      ? AppColors.primaryForeground
                      : AppColors.text,
                ),
                onSelected: (_) => onChanged(option),
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
    this.iconColor = AppColors.primary,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.xxs,
    ),
    leading: StudioIconTile(icon: icon, color: iconColor),
    title: Text(title, style: AppTypography.bodyEmphasis),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: AppTypography.caption.copyWith(color: AppColors.muted),
          ),
    trailing: value == null
        ? (onTap == null
              ? null
              : const Icon(
                  Icons.chevron_right,
                  size: AppIconSize.medium,
                  color: AppColors.muted,
                ))
        : Switch(value: value!, onChanged: onChanged),
    onTap: onTap,
  );
}

class MockBanner extends StatelessWidget {
  const MockBanner({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Text(
      'DEMO LIBRARY · Sample media · UI settings only',
      style: AppTypography.mutedMicro,
    ),
  );
}

class MediaPreview extends StatelessWidget {
  const MediaPreview({
    super.key,
    required this.asset,
    required this.duration,
    this.onTap,
    this.badge = '1080p · 60 FPS',
  });

  final String asset;
  final String duration;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.control),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.mediaScrim),
          ),
          Positioned(top: 8, left: 8, child: StudioBadge(badge)),
          Center(
            child: IconButton.filledTonal(
              tooltip: 'Preview sample',
              onPressed: onTap,
              iconSize: AppIconSize.preview,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Text(
              duration,
              style: AppTypography.timecode.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: Text(
              'FHD 1080p  •  Stereo',
              style: AppTypography.primaryCaption,
            ),
          ),
        ],
      ),
    ),
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
    duration: duration,
    switchInCurve: AppMotion.enter,
    switchOutCurve: AppMotion.exit,
    child: child,
  );
}
