import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import 'settings_controller.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    void av() => context.push('/settings/audio-video');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(
          'Settings Hub',
          trailing: StudioBadge('v0.1.0', color: AppColors.primary),
        ),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ScreenFlow Pro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StudioBadge('ULTRA', color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Unlock 4K 120FPS capture, zero watermark, lossless 24-bit audio tracks, and custom RTMP multi-streaming.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                'Upgrade to Pro',
                icon: Icons.bolt,
                onPressed: () => unsupported(context, 'Subscriptions'),
              ),
            ],
          ),
        ),
        const MockBanner(),
        _label('VIDEO & AUDIO CONFIGURATION'),
        _group([
          SettingsRow(
            'Resolution & Video Quality',
            icon: Icons.video_settings,
            subtitle: '${s.resolution} • ${s.fps} FPS • ${s.bitrate}',
            onTap: av,
          ),
          SettingsRow(
            'Audio Source & Volume',
            icon: Icons.mic_none,
            subtitle: '${s.audio} • ${s.gain.round()}% gain',
            onTap: av,
          ),
          SettingsRow(
            'Audio Noise Reduction',
            icon: Icons.graphic_eq,
            subtitle: 'UI preference · No audio processing',
            value: s.noise,
            onChanged: (v) => s.update(() => s.noise = v),
          ),
          SettingsRow(
            'Orientation',
            icon: Icons.screen_rotation,
            subtitle: s.orientation,
            onTap: av,
          ),
        ]),
        _label('RECORDING & GESTURE CONTROLS'),
        _group([
          SettingsRow(
            'Floating Ball & HUD',
            icon: Icons.radio_button_checked,
            subtitle: 'Custom size, opacity, dock to edge',
            onTap: () => unsupported(context, 'Floating overlay'),
          ),
          SettingsRow(
            'Countdown Timer',
            icon: Icons.timer_outlined,
            subtitle: s.countdown == 'Off'
                ? 'Off'
                : '${s.countdown.replaceAll('s', '')} seconds',
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ChoiceGroup(
                    label: 'Countdown Timer',
                    options: const ['Off', '3s', '5s', '10s'],
                    value: s.countdown,
                    onChanged: (v) {
                      s.update(() => s.countdown = v);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
          ),
          SettingsRow(
            'Shake to Stop Recording',
            icon: Icons.vibration,
            subtitle: 'UI preference · Gesture engine pending',
            value: s.shake,
            onChanged: (v) => s.update(() => s.shake = v),
          ),
          SettingsRow(
            'Keep Recording Screen Off',
            icon: Icons.screen_lock_portrait,
            subtitle: 'UI preference · No background service',
            value: s.screenOff,
            onChanged: (v) => s.update(() => s.screenOff = v),
          ),
          SettingsRow(
            'Show Screen Touches',
            icon: Icons.fingerprint,
            subtitle: 'Requires native implementation',
            onTap: () => unsupported(context, 'Screen touches'),
          ),
        ]),
        _label('STORAGE & ADVANCED'),
        _group([
          SettingsRow(
            'Storage Directory',
            icon: Icons.folder_outlined,
            subtitle: 'Sample path · DCIM/ScreenFlow',
            onTap: () => unsupported(context, 'Storage selection'),
          ),
          SettingsRow(
            'Live RTMP Streaming',
            icon: Icons.stream,
            subtitle: 'Stream to YouTube, Twitch, Kick',
            onTap: () => unsupported(context, 'RTMP streaming'),
          ),
          SettingsRow(
            'Crash Prevention Cache',
            icon: Icons.shield_outlined,
            subtitle: 'UI preference · Capture engine pending',
            value: s.cache,
            onChanged: (v) => s.update(() => s.cache = v),
          ),
        ]),
        _label('ABOUT & SUPPORT'),
        _group([
          SettingsRow(
            'FAQ & User Guide',
            icon: Icons.quiz_outlined,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('XRecorder baseline'),
                content: const Text(
                  'Browse sample videos and photos, open Record to configure a session, and adjust settings. Capture, playback, editing, sharing, and export engines are not connected. UI preferences reset when the app restarts.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          SettingsRow(
            'Language',
            icon: Icons.translate,
            subtitle: 'English (US)',
            onTap: () => unsupported(context, 'Additional languages'),
          ),
          SettingsRow(
            'App Version',
            icon: Icons.verified_outlined,
            subtitle: 'v0.1.0 (Build 1) · Flutter UI baseline',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'XRecorder',
              applicationVersion: '0.1.0+1',
              children: [
                const Text(
                  'Native Flutter baseline based on the supplied Stitch ScreenFlow design.',
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'XRecorder · Studio UI baseline',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: .8,
      ),
    ),
  );
  Widget _group(List<Widget> rows) => StudioCard(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          rows[i],
        ],
      ],
    ),
  );
}
