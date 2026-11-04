import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import 'media_library_screen.dart';

class PhotoLibraryScreen extends StatelessWidget {
  const PhotoLibraryScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const MediaLibraryScreen(kind: MediaKind.image);
}
