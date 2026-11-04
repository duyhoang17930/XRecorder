import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../media/media_library_screen.dart';

class VideoHomeScreen extends StatelessWidget {
  const VideoHomeScreen({super.key, this.empty = false});
  final bool empty;
  @override
  Widget build(BuildContext context) =>
      const MediaLibraryScreen(kind: MediaKind.video);
}
