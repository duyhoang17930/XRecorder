import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/repositories.dart';
import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../../l10n/localization.dart';
import '../settings/settings_controller.dart';
import 'recording_service.dart';

final _regionRoutes = Expando<bool>();

Future<void> openRegionCapture(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (_regionRoutes[navigator] == true || CaptureScope.of(context).busy) return;
  _regionRoutes[navigator] = true;
  try {
    await navigator.push<void>(
      MaterialPageRoute(builder: (_) => const RegionCapturePage()),
    );
  } finally {
    _regionRoutes[navigator] = false;
  }
}

class RegionCapturePage extends StatefulWidget {
  const RegionCapturePage({super.key});

  @override
  State<RegionCapturePage> createState() => _RegionCapturePageState();
}

class _RegionCapturePageState extends State<RegionCapturePage> {
  Future<({int width, int height})>? _display;
  Rect _region = const Rect.fromLTWH(.1, .15, .8, .5);
  bool _starting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = CaptureScope.of(context).service;
    _display ??= service is RegionRecordingService
        ? (service as RegionRecordingService).captureDisplay()
        : Future.error(StateError('Region recording requires Android.'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.regionCapture),
      leading: IconButton(
        tooltip: context.l10n.close,
        onPressed: _starting ? null : () => Navigator.pop(context),
        icon: const BackButtonIcon(),
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<({int width, int height})>(
        future: _display,
        builder: (context, snapshot) {
          final display = snapshot.data;
          if (snapshot.hasError) {
            return Center(child: Text(context.l10n.regionUnavailable));
          }
          if (display == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final minWidth = math.min(1.0, 160 / display.width);
          final minHeight = math.min(1.0, 160 / display.height);
          Rect pixels() => Rect.fromLTWH(
            (_region.left * display.width).floorToDouble(),
            (_region.top * display.height).floorToDouble(),
            math.max(160, (_region.width * display.width).floor() ~/ 2 * 2.0),
            math.max(160, (_region.height * display.height).floor() ~/ 2 * 2.0),
          );
          Widget slider(
            String label,
            double value,
            double minimum,
            double maximum,
            ValueChanged<double> update,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label · ${context.displayValue((value * 100).round())}%'),
              Slider(
                label: label,
                semanticFormatterCallback: context.spokenValue(
                  (_, v) => '$label $v%',
                  multiplier: 100,
                ),
                min: minimum,
                max: math.max(minimum, maximum),
                value: value.clamp(minimum, math.max(minimum, maximum)),
                onChanged: _starting || maximum <= minimum
                    ? null
                    : (v) => setState(() => update(v)),
              ),
            ],
          );
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.regionCaptureHint),
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          height: 220,
                          child: AspectRatio(
                            aspectRatio: display.width / display.height,
                            child: LayoutBuilder(
                              builder: (context, bounds) => Semantics(
                                label:
                                    '${context.l10n.regionCapture} ${pixels().width.toInt()} × ${pixels().height.toInt()}',
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: context.studioColors.surface,
                                          border: Border.all(
                                            color: context.studioColors.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: _region.left * bounds.maxWidth,
                                      top: _region.top * bounds.maxHeight,
                                      width: _region.width * bounds.maxWidth,
                                      height: _region.height * bounds.maxHeight,
                                      child: GestureDetector(
                                        onPanUpdate: _starting
                                            ? null
                                            : (event) => setState(() {
                                                _region = Rect.fromLTWH(
                                                  (_region.left +
                                                          event.delta.dx /
                                                              bounds.maxWidth)
                                                      .clamp(
                                                        0,
                                                        1 - _region.width,
                                                      ),
                                                  (_region.top +
                                                          event.delta.dy /
                                                              bounds.maxHeight)
                                                      .clamp(
                                                        0,
                                                        1 - _region.height,
                                                      ),
                                                  _region.width,
                                                  _region.height,
                                                );
                                              }),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: context.studioColors.primary
                                                .withValues(alpha: .25),
                                            border: Border.all(
                                              color:
                                                  context.studioColors.primary,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(AppIcons.region),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      slider(
                        context.l10n.regionWidth,
                        _region.width,
                        minWidth,
                        1,
                        (v) {
                          _region = Rect.fromLTWH(
                            math.min(_region.left, 1 - v),
                            _region.top,
                            v,
                            _region.height,
                          );
                        },
                      ),
                      slider(
                        context.l10n.regionHeight,
                        _region.height,
                        minHeight,
                        1,
                        (v) {
                          _region = Rect.fromLTWH(
                            _region.left,
                            math.min(_region.top, 1 - v),
                            _region.width,
                            v,
                          );
                        },
                      ),
                      slider(
                        context.l10n.horizontalPosition,
                        _region.left,
                        0,
                        1 - _region.width,
                        (v) {
                          _region = Rect.fromLTWH(
                            v,
                            _region.top,
                            _region.width,
                            _region.height,
                          );
                        },
                      ),
                      slider(
                        context.l10n.verticalPosition,
                        _region.top,
                        0,
                        1 - _region.height,
                        (v) {
                          _region = Rect.fromLTWH(
                            _region.left,
                            v,
                            _region.width,
                            _region.height,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                  context.l10n.recordScreen,
                  icon: AppIcons.record,
                  onPressed: _starting
                      ? null
                      : () async {
                          setState(() => _starting = true);
                          try {
                            final capture = CaptureScope.of(context);
                            final adapter =
                                capture.service as RegionRecordingService;
                            final current = await adapter.captureDisplay();
                            if (current != display) {
                              if (context.mounted) {
                                setState(() {
                                  _display = Future.value(current);
                                });
                              }
                              throw const DomainFailure(
                                FailureCode.invalid,
                                'The screen size changed. Select the capture region again.',
                              );
                            }
                            if (!context.mounted) return;
                            await capture.startRegion(
                              SettingsScope.of(context).recordingSnapshot,
                              pixels(),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (error) {
                            if (context.mounted) {
                              showFailure(
                                context,
                                error,
                                operation: UserOperation.recording,
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _starting = false);
                          }
                        },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
