import 'package:flutter/material.dart';

import '../../../constants/app_icons.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: AppShadows.card(context),
    ),
    child: Material(
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
    ),
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

/// Branding for the four shell roots; nested pages retain their own AppBar.
class StudioRootHeader extends StatelessWidget {
  const StudioRootHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '3HRECORDER',
        style: AppTypography.section.copyWith(
          color: context.studioColors.primary,
        ),
      ),
      SectionTitle(
        title,
        trailing: trailing,
        minimumHeight: AppSize.touchTarget,
      ),
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.minimumHeight = 0,
  });
  final String title;
  final Widget? trailing;
  final double minimumHeight;
  @override
  Widget build(BuildContext context) {
    final heading = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minimumHeight),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
    // Long translated counts/actions must not consume the entire heading row
    // at large text sizes. Both pieces keep full text and their touch targets.
    final stacked =
        trailing != null && MediaQuery.textScalerOf(context).scale(14) > 20;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: AppSpacing.xxs),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: heading),
                ?trailing,
              ],
            ),
    );
  }
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
