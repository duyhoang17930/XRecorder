import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Shield the opening control's location above the modal AND its scrim. A sheet
/// can still be sliding below that point when the next tap in a burst arrives.
T runStudioSheetLaunch<T>(BuildContext origin, T Function() launch) {
  final box = origin.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return launch();
  final region = box.localToGlobal(Offset.zero) & box.size;
  final overlay = Overlay.of(origin, rootOverlay: true);
  final result = launch();
  late final OverlayEntry shield;
  shield = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: StudioSheetOpeningGuard(
        region: region.inflate(8),
        onExpired: () {
          shield.remove();
          shield.dispose();
        },
        child: const SizedBox.expand(),
      ),
    ),
  );
  overlay.insert(shield);
  return result;
}

/// Only the opening button's location is shielded during its tap burst. Other
/// sheet controls respond immediately, including when Reduce Motion is on.
class StudioSheetOpeningGuard extends StatefulWidget {
  const StudioSheetOpeningGuard({
    super.key,
    required this.region,
    required this.child,
    this.onExpired,
  });
  final Rect region;
  final Widget child;
  final VoidCallback? onExpired;

  @override
  State<StudioSheetOpeningGuard> createState() =>
      _StudioSheetOpeningGuardState();
}

class _StudioSheetOpeningGuardState extends State<StudioSheetOpeningGuard> {
  Timer? _quiet;
  bool _guarding = true;

  @override
  void initState() {
    super.initState();
    _restartQuietPeriod();
  }

  void _restartQuietPeriod() {
    _quiet?.cancel();
    _quiet = Timer(kDoubleTapTimeout, () {
      if (mounted) {
        setState(() => _guarding = false);
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _quiet?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _OpeningTapRegion(
    region: _guarding ? widget.region : null,
    onSuppressedDown: _restartQuietPeriod,
    child: widget.child,
  );
}

class _OpeningTapRegion extends SingleChildRenderObjectWidget {
  const _OpeningTapRegion({
    required this.region,
    required this.onSuppressedDown,
    required super.child,
  });
  final Rect? region;
  final VoidCallback onSuppressedDown;

  @override
  _OpeningTapRenderBox createRenderObject(BuildContext context) =>
      _OpeningTapRenderBox(region, onSuppressedDown);

  @override
  void updateRenderObject(
    BuildContext context,
    _OpeningTapRenderBox renderObject,
  ) {
    renderObject
      ..region = region
      ..onSuppressedDown = onSuppressedDown;
  }
}

class _OpeningTapRenderBox extends RenderProxyBox {
  _OpeningTapRenderBox(this.region, this.onSuppressedDown);
  Rect? region;
  VoidCallback onSuppressedDown;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position) &&
        region?.contains(localToGlobal(position)) == true) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) onSuppressedDown();
  }
}
