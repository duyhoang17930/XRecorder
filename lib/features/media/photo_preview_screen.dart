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
    appBar: AppBar(title: const Text('Photo preview')),
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
                  UserMessages.failure(
                    snapshot.error,
                    operation: UserOperation.loadPhoto,
                  ).text,
                ),
                TextButton(onPressed: retry, child: const Text('Retry')),
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
                  const Text('Could not open this image. Try another photo.'),
                  TextButton(onPressed: retry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
