import 'package:flutter/material.dart';

/// Session-only UI configuration. Future capture engines can consume this model.
class SettingsController extends ChangeNotifier {
  String resolution = '1080p FHD';
  String fps = '60';
  String bitrate = '16 Mbps';
  String codec = 'H.264 / AVC';
  String orientation = 'Auto Sensor';
  String audio = 'Mixed Stream';
  String countdown = '3s';
  double gain = 140;
  bool cfr = true;
  bool hardware = true;
  bool noise = true;
  bool shake = true;
  bool screenOff = false;
  bool touches = false;
  bool cache = true;

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  void reset() {
    update(() {
      resolution = '1080p FHD';
      fps = '60';
      bitrate = '16 Mbps';
      codec = 'H.264 / AVC';
      orientation = 'Auto Sensor';
      audio = 'Mixed Stream';
      countdown = '3s';
      gain = 140;
      cfr = true;
      hardware = true;
      noise = true;
      shake = true;
      screenOff = false;
      touches = false;
      cache = true;
    });
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);
  static SettingsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
