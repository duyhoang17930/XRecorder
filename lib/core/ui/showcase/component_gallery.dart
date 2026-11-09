import 'package:flutter/material.dart';
import 'package:xrecorder/l10n/localization.dart';

import '../../constants/app_icons.dart';
import '../components/components.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  final _searchController = TextEditingController(text: 'Studio');
  String _choice = '1080p';
  String _dropdownValue = 'Balanced';
  bool _switchValue = true;
  double _sliderValue = .62;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.studioColors;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.componentGallery)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Shared components in Light and Dark themes',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          _section(context, 'Semantic colors'),
          StudioCard(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _ColorSwatch(label: 'Background', color: colors.background),
                _ColorSwatch(label: 'Surface', color: colors.surface),
                _ColorSwatch(label: 'Card', color: colors.card),
                _ColorSwatch(label: 'Elevated', color: colors.elevated),
                _ColorSwatch(label: 'Primary', color: colors.primary),
                _ColorSwatch(label: 'Cyan', color: colors.cyan),
                _ColorSwatch(label: 'Warning', color: colors.warning),
              ],
            ),
          ),
          _section(context, 'Buttons and actions'),
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  'Primary action',
                  onPressed: () {},
                  icon: AppIcons.forward,
                ),
                const SizedBox(height: AppSpacing.xs),
                RecordActionButton(onPressed: () {}, label: 'Record action'),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(AppIcons.edit),
                  label: const Text('Outlined action'),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Text action'),
                    ),
                    IconButton(
                      tooltip: 'More actions',
                      onPressed: () {},
                      icon: const Icon(AppIcons.more),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Open menu',
                      onSelected: (_) {},
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'share', child: Text('Share')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          _section(context, 'Inputs and selection'),
          StudioCard(
            child: Column(
              children: [
                StudioTextField(labelText: 'Name', hintText: 'Enter a name'),
                const SizedBox(height: AppSpacing.sm),
                StudioSearchField(
                  controller: _searchController,
                  hintText: 'Search components',
                ),
                const SizedBox(height: AppSpacing.sm),
                StudioDropdown<String>(
                  value: _dropdownValue,
                  labelText: 'Quality preset',
                  items: const [
                    DropdownMenuItem(value: 'Compact', child: Text('Compact')),
                    DropdownMenuItem(
                      value: 'Balanced',
                      child: Text('Balanced'),
                    ),
                    DropdownMenuItem(
                      value: 'High quality',
                      child: Text('High quality'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _dropdownValue = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ChoiceGroup(
                  label: 'Resolution',
                  options: const ['720p', '1080p', '2K'],
                  value: _choice,
                  onChanged: (value) => setState(() => _choice = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include system audio'),
                  value: _switchValue,
                  onChanged: (value) => setState(() => _switchValue = value),
                ),
                Slider(
                  value: _sliderValue,
                  onChanged: (value) => setState(() => _sliderValue = value),
                ),
              ],
            ),
          ),
          _section(context, 'Cards and status'),
          StudioBentoGrid(
            children: [
              BentoCard(
                title: 'Media card',
                description: 'Rounded, outlined surface',
                icon: AppIcons.video,
                badge: 'Example',
                onTap: () {},
              ),
              BentoCard(
                title: 'Editor card',
                description: 'Uses the same spacing tokens',
                icon: AppIcons.edit,
                accent: colors.cyan,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RecordingStatusIndicator(label: 'Ready to record'),
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(value: .62),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    StudioBadge('Saved', color: colors.cyan),
                    StudioBadge('Warning', color: colors.warning),
                  ],
                ),
              ],
            ),
          ),
          _section(context, 'Dialogs and bottom sheets'),
          StudioCard(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.tonal(
                  onPressed: () => showStudioDialog<void>(
                    context: context,
                    builder: (dialogContext) => StudioDialog(
                      title: const Text('Confirmation dialog'),
                      icon: AppIcons.info,
                      content: const Text(
                        'This dialog uses the shared surface, spacing and actions.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Show dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => showStudioBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StudioSheetHeader(
                              title: 'Action sheet',
                              description: 'Shared handle and rounded surface',
                              actions: [
                                IconButton(
                                  tooltip: 'Close sheet',
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(AppIcons.close),
                                ),
                              ],
                            ),
                            const SettingsRow(
                              'Example action',
                              icon: AppIcons.edit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Show bottom sheet'),
                ),
              ],
            ),
          ),
          _section(context, 'Empty state'),
          const StudioEmptyState(
            title: 'Nothing here yet',
            description: 'Add media to see it appear in this library.',
            icon: AppIcons.folderOpen,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => StudioSectionLabel(
    title,
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
  );
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: Border.all(color: context.studioColors.border),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color:
            color == context.studioColors.background ||
                color == context.studioColors.card
            ? context.studioColors.text
            : color == context.studioColors.primary ||
                  color == context.studioColors.warning
            ? Colors.white
            : context.studioColors.text,
      ),
    ),
  );
}
