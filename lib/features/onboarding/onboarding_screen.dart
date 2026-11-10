import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/theme/colors.dart';
import '../../core/ui/theme/motion.dart';
import '../../core/ui/theme/radius.dart';
import '../../core/ui/theme/spacing.dart';
import '../../core/ui/theme/typography.dart';
import '../../l10n/localization.dart';
import 'onboarding_store.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.store,
    required this.initialPage,
    required this.onCompleted,
    this.replay = false,
  });

  final OnboardingStore store;
  final int initialPage;
  final VoidCallback onCompleted;
  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pages = PageController(
    initialPage: widget.initialPage.clamp(0, 2).toInt(),
  );
  late final AnimationController _artMotion = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late int _page = widget.initialPage.clamp(0, 2).toInt();
  Future<void> _saveQueue = Future<void>.value();
  bool _transitioning = false;
  bool _completing = false;
  bool _saveFailed = false;
  bool _reduceMotion = false;
  bool _motionInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_motionInitialized && reduceMotion == _reduceMotion) return;
    _motionInitialized = true;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _artMotion
        ..stop()
        ..value = 1;
    } else {
      _artMotion
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _artMotion.dispose();
    super.dispose();
  }

  void _persistPage(int page) {
    final write = _saveQueue.then((_) => widget.store.savePage(page));
    _saveQueue = write.catchError((Object _) {
      if (mounted) setState(() => _saveFailed = true);
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _page = page;
      _saveFailed = false;
    });
    _persistPage(page);
    if (!_reduceMotion) {
      _artMotion
        ..reset()
        ..forward();
    } else {
      _artMotion.value = 1;
    }
  }

  Future<void> _goTo(int page) async {
    if (_transitioning ||
        _completing ||
        page < 0 ||
        page > 2 ||
        page == _page) {
      return;
    }
    _transitioning = true;
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(page);
      } else {
        await _pages.animateToPage(
          page,
          duration: AppMotion.slow,
          curve: AppMotion.emphasized,
        );
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<void> _finish() async {
    if (_completing) return;
    setState(() {
      _completing = true;
      _saveFailed = false;
    });
    try {
      await _saveQueue;
      await widget.store.complete();
      if (mounted) widget.onCompleted();
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.studioColors;
    final backgroundColor = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFFAF9F6)
        : colors.background;
    final strings = context.l10n;

    return PopScope<Object?>(
      canPop: widget.replay && _page == 0 && !_completing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _goTo(_page - 1);
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final landscape = constraints.maxWidth > constraints.maxHeight;
              final artHeight = (constraints.maxHeight * .42)
                  .clamp(landscape ? 96.0 : 176.0, 300.0)
                  .toDouble();
              return Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bodyConstraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: bodyConstraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  height: AppSize.touchTarget,
                                  child: Row(
                                    textDirection: TextDirection.ltr,
                                    children: [
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _completing ? null : _finish,
                                        style: TextButton.styleFrom(
                                          minimumSize: const Size(
                                            AppSize.touchTarget,
                                            AppSize.touchTarget,
                                          ),
                                          foregroundColor: colors.muted,
                                        ),
                                        child: Text(strings.onboardingSkip),
                                      ),
                                    ],
                                  ),
                                ),
                                Flex(
                                  direction: landscape
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      flex: landscape ? 2 : 1,
                                      fit: FlexFit.loose,
                                      child: SizedBox(
                                        height: artHeight,
                                        child: PageView.builder(
                                          controller: _pages,
                                          itemCount: 3,
                                          onPageChanged: _onPageChanged,
                                          itemBuilder: (context, index) {
                                            final dpr =
                                                MediaQuery.devicePixelRatioOf(
                                                  context,
                                                );
                                            final cacheWidth =
                                                (constraints.maxWidth * dpr)
                                                    .round()
                                                    .clamp(3, 1200)
                                                    .toInt();
                                            final image = Image.asset(
                                              _illustrationAsset(index),
                                              key: ValueKey(
                                                'onboarding-art-$index',
                                              ),
                                              fit: BoxFit.contain,
                                              alignment: Alignment.center,
                                              cacheWidth: cacheWidth,
                                              filterQuality:
                                                  FilterQuality.medium,
                                            );
                                            return Semantics(
                                              label:
                                                  '${_title(strings, index)}. ${_description(strings, index)}',
                                              image: true,
                                              child: ExcludeSemantics(
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    final imageWidth =
                                                        constraints.maxWidth <
                                                            constraints
                                                                    .maxHeight *
                                                                1.5
                                                        ? constraints.maxWidth
                                                        : constraints
                                                                  .maxHeight *
                                                              1.5;
                                                    final imageHeight =
                                                        imageWidth / 1.5;
                                                    final verticalInset =
                                                        (constraints.maxHeight -
                                                            imageHeight) /
                                                        2;
                                                    return FadeTransition(
                                                      opacity: Tween<double>(
                                                        begin: .88,
                                                        end: 1,
                                                      ).animate(_artMotion),
                                                      child: ScaleTransition(
                                                        scale: Tween<double>(
                                                          begin: .97,
                                                          end: 1,
                                                        ).animate(_artMotion),
                                                        child: Stack(
                                                          clipBehavior:
                                                              Clip.none,
                                                          children: [
                                                            Positioned.fill(
                                                              child: image,
                                                            ),
                                                            if (index == 0)
                                                              Positioned(
                                                                right:
                                                                    (constraints.maxWidth -
                                                                            imageWidth) /
                                                                        2 +
                                                                    imageWidth *
                                                                        .32,
                                                                top:
                                                                    verticalInset +
                                                                    imageHeight *
                                                                        .425,
                                                                child: const Text(
                                                                  'REC',
                                                                  style: TextStyle(
                                                                    color: Color(
                                                                      0xFF352E2D,
                                                                    ),
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    letterSpacing:
                                                                        .8,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppSpacing.md,
                                      width: AppSpacing.md,
                                    ),
                                    Flexible(
                                      flex: landscape ? 3 : 1,
                                      fit: FlexFit.loose,
                                      child: AnimatedSwitcher(
                                        duration: context.motion(
                                          AppMotion.standard,
                                        ),
                                        child: Column(
                                          key: ValueKey(_page),
                                          children: [
                                            Text(
                                              _title(strings, _page),
                                              textAlign: TextAlign.center,
                                              style: AppTypography.display
                                                  .copyWith(color: colors.text),
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 360,
                                              ),
                                              child: Text(
                                                _description(strings, _page),
                                                textAlign: TextAlign.center,
                                                style: AppTypography.body
                                                    .copyWith(
                                                      fontSize: 16,
                                                      color: colors.muted,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Semantics(
                                  label: strings.onboardingProgress(
                                    context.displayValue(_page + 1),
                                    context.displayValue(3),
                                  ),
                                  child: ExcludeSemantics(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        3,
                                        (index) => AnimatedContainer(
                                          duration: context.motion(
                                            AppMotion.fast,
                                          ),
                                          curve: AppMotion.emphasized,
                                          width: index == _page ? 28 : 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: index == _page
                                                ? colors.primary
                                                : colors.border,
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.pill,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (_saveFailed) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: Text(
                                      strings.onboardingSaveFailed,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: colors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _primaryAction(strings),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _primaryAction(AppLocalizations strings) => Center(
    child: SizedBox(
      width: 220,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(180, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        onPressed: _completing || _transitioning
            ? null
            : _page == 2
            ? _finish
            : () => _goTo(_page + 1),
        child: Text(
          _page == 2 ? strings.onboardingGetStarted : strings.onboardingNext,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  String _title(AppLocalizations strings, int page) => switch (page) {
    0 => strings.onboardingRecordTitle,
    1 => strings.onboardingEditTitle,
    _ => strings.onboardingSubtitlesTitle,
  };

  String _description(AppLocalizations strings, int page) => switch (page) {
    0 => strings.onboardingRecordDescription,
    1 => strings.onboardingEditDescription,
    _ => strings.onboardingSubtitlesDescription,
  };
}

String _illustrationAsset(int page) => switch (page) {
  0 => 'assets/images/onboarding/record_anything_v1.png',
  1 => 'assets/images/onboarding/edit_your_way_v1.png',
  _ => 'assets/images/onboarding/smart_subtitles_v1.png',
};
