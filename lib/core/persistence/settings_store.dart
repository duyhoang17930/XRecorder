import 'package:flutter/services.dart';

/// Stores one versioned, non-sensitive preferences document atomically.
abstract interface class SettingsStore {
  Future<String?> read();
  Future<void> write(String document);
}

class AndroidSettingsStore implements SettingsStore {
  const AndroidSettingsStore();
  static const channel = MethodChannel('com.xrecorder/settings');

  @override
  Future<String?> read() => channel.invokeMethod<String>('read');

  @override
  Future<void> write(String document) =>
      channel.invokeMethod<void>('write', document);
}
