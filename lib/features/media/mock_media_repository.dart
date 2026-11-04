class MediaItem {
  const MediaItem({
    required this.id,
    required this.name,
    required this.asset,
    required this.duration,
    required this.size,
    required this.category,
    required this.time,
    this.fps = '60',
    this.resolution = '1920 × 1080',
  });
  final String id, name, asset, duration, size, category, time, fps, resolution;
}

abstract final class MockMediaRepository {
  static const videos = [
    MediaItem(
      id: 'pubg',
      name: 'PUBG_Clutch_FinalCircle_1080p.mp4',
      asset: 'assets/media/video_0.jpg',
      duration: '08:42',
      size: '342 MB',
      category: 'Gameplay',
      time: 'Today, 14:28',
    ),
    MediaItem(
      id: 'bug',
      name: 'App_BugReport_Checkout_Repro.mp4',
      asset: 'assets/media/video_1.jpg',
      duration: '01:15',
      size: '28 MB',
      category: 'Work',
      time: 'Today, 11:05',
      fps: '30',
      resolution: '1280 × 720',
    ),
    MediaItem(
      id: 'tutorial',
      name: 'Tutorial_Flutter_CustomPaint.mp4',
      asset: 'assets/media/video_2.jpg',
      duration: '14:20',
      size: '610 MB',
      category: 'Tutorial',
      time: 'Yesterday',
    ),
  ];
  static const completed = MediaItem(
    id: 'apex',
    name: 'Apex_Velocity_Sector04_Drift.mp4',
    asset: 'assets/media/completed_0.jpg',
    duration: '04:20',
    size: '142.8 MB',
    category: 'Gameplay',
    time: 'Today, 09:41',
  );
  static MediaItem? find(String id) {
    if (id == completed.id) return completed;
    for (final video in videos) {
      if (video.id == id) return video;
    }
    return null;
  }

  static const photos = [
    'CyberStrike_04.png',
    'debug_stack_01.png',
    'TxConfirm_99.png',
    'padding_bug_v2.png',
    'documentary_frame.png',
    'vulkan_bench_core.png',
  ];
}
