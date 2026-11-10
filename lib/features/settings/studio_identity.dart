import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/localization.dart';

abstract final class StudioIdentity {
  static const name = 'MxT APP';
  static const email = 'maixuantruongcvdev@gmail.com';
  static const website = 'https://mxtapp.website/';
  static const privacy = 'https://mxtapp.website/privacy-policy.html';
  static const terms = 'https://mxtapp.website/terms-of-use.html';
  static const channel = MethodChannel('com.xrecorder/support');
}

Future<void> openStudioLink(BuildContext context, String url) async {
  try {
    await StudioIdentity.channel.invokeMethod<void>('openStudioLink', url);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.openExternalFailed)));
    }
  }
}
