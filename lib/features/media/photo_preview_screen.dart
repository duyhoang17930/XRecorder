import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhotoPreviewScreen extends StatefulWidget {
  const PhotoPreviewScreen({super.key, required this.uri});
  final String uri;
  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  late final data = const MethodChannel('com.xrecorder/media')
      .invokeMethod<Uint8List>('imageBytes', {'uri': widget.uri});
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
          return const Center(
            child: Text('Image unavailable, too large, or access revoked.'),
          );
        }
        return Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              cacheWidth: 2048,
              errorBuilder: (_, _, _) =>
                  const Text('Image could not be decoded.'),
            ),
          ),
        );
      },
    ),
  );
}
