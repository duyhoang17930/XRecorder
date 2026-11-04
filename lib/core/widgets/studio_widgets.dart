import 'package:flutter/material.dart';

import '../constants/design_tokens.dart';

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(AppRadius.card),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
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
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
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

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
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
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: options
            .map(
              (option) => ChoiceChip(
                label: Text(option),
                selected: value == option,
                labelStyle: TextStyle(
                  color: value == option
                      ? const Color(0xFF391300)
                      : AppColors.text,
                  fontSize: 12,
                ),
                onSelected: (_) => onChanged(option),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
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
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
    trailing: value == null
        ? const Icon(Icons.chevron_right, size: 20, color: AppColors.muted)
        : Switch(value: value!, onChanged: onChanged),
    onTap: onTap,
  );
}

class MockBanner extends StatelessWidget {
  const MockBanner({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'DEMO LIBRARY · Sample media · UI settings only',
      style: TextStyle(fontSize: 10, color: AppColors.muted),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(top: 8, left: 8, child: StudioBadge(badge)),
          Center(
            child: IconButton.filledTonal(
              tooltip: 'Preview sample',
              onPressed: onTap,
              iconSize: 36,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Text(
              duration,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: Text(
              'FHD 1080p  •  Stereo',
              style: TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ),
        ],
      ),
    ),
  );
}
