import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Localizes P2 native surfaces without recreating MainActivity or capture.
class NativeLocaleSync extends StatefulWidget {
  const NativeLocaleSync({super.key, required this.child});
  final Widget child;
  @override
  State<NativeLocaleSync> createState() => _NativeLocaleSyncState();
}

class _NativeLocaleSyncState extends State<NativeLocaleSync> {
  String? _last;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tag = Localizations.localeOf(context).toLanguageTag();
    if (_last != tag) {
      _last = tag;
      unawaited(_sync(tag));
    }
  }

  Future<void> _sync(String tag) async {
    try {
      await const MethodChannel('com.xrecorder/media')
          .invokeMethod<void>('setAppLocale', tag);
    } on MissingPluginException {
      // Widget tests and unsupported host platforms have no Android surface.
    } on PlatformException {
      // Flutter copy remains usable if native preferences cannot be persisted.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
