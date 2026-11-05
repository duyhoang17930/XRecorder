import 'package:flutter/material.dart';

/// One controller per retained shell branch, independent of the selected tab.
class StudioTabScrollScope extends InheritedWidget {
  const StudioTabScrollScope({
    super.key,
    required this.controllers,
    required super.child,
  });
  final List<ScrollController> controllers;
  static List<ScrollController> of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StudioTabScrollScope>()!
      .controllers;
  @override
  bool updateShouldNotify(StudioTabScrollScope oldWidget) =>
      controllers != oldWidget.controllers;
}

class StudioTabScroll extends StatelessWidget {
  const StudioTabScroll({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: StudioTabScrollScope.of(context)[index],
    child: child,
  );
}
