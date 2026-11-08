import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/studio_widgets.dart';

class PhotoPreviewScreen extends StatefulWidget {
  const PhotoPreviewScreen({super.key, required this.uri});
  final String uri;
  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  late var data = read();
  Future<Uint8List?> read() =>
      const MethodChannel('com.xrecorder/media')
          .invokeMethod<Uint8List>('imageBytes', {'uri': widget.uri});
  void retry() {
    final next = read();
    setState(() {
      data = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.photoPreview)),
    body: FutureBuilder<Uint8List?>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.message(
                    UserMessages.failure(
                      snapshot.error,
                      operation: UserOperation.loadPhoto,
                    ).text,
                  ),
                ),
                TextButton(onPressed: retry, child: Text(context.l10n.retry)),
              ],
            ),
          );
        }
        return Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              cacheWidth: 2048,
              errorBuilder: (_, _, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.couldNotOpenThisImageTryAnother),
                  TextButton(onPressed: retry, child: Text(context.l10n.retry)),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
