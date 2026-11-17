import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/theme/motion.dart';

/// Keeps each branch Navigator mounted while adjacent tab pages slide.
class StudioTabTransition extends StatefulWidget {
  const StudioTabTransition({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<StudioTabTransition> createState() => _StudioTabTransitionState();
}

class _StudioTabTransitionState extends State<StudioTabTransition> {
  late Set<int> _visible = {widget.index};
  Timer? _settle;

  Duration get _duration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : AppMotion.navigationIndicator;

  @override
  void didUpdateWidget(StudioTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _visible = {oldWidget.index, widget.index};
    _settle?.cancel();
    _settle = Timer(_duration, () {
      if (mounted) setState(() => _visible = {widget.index});
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: !_visible.contains(i),
            child: AnimatedSlide(
              key: ValueKey('tab-slide-$i'),
              offset: i == widget.index
                  ? Offset.zero
                  : Offset(i < widget.index ? -1 : 1, 0),
              duration: _duration,
              curve: AppMotion.emphasized,
              child: TickerMode(
                enabled: i == widget.index,
                child: IgnorePointer(
                  ignoring: i != widget.index,
                  child: ExcludeSemantics(
                    excluding: i != widget.index,
                    child: widget.children[i],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
