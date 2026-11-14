import 'models.dart';

/// Adapters throw DomainFailure for actionable errors; null means not found.
abstract interface class MediaRepository {
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder});
  Future<MediaItem?> find(String id);
  Stream<void> get changes;
  Future<Uri?> selectFolder(); // null means picker cancelled.
}

abstract interface class RecordingService {
  Future<RecordingCapabilities> capabilities();
  Future<RecordingSession?> currentSession();
  Stream<RecordingSession> get sessions;
  Future<RecordingSession> start(RecordingSettings settings);
  Future<RecordingSession> screenshot();
  Future<void> pause(String sessionId);
  Future<void> resume(String sessionId);
  Future<void> stop(String sessionId);
  Future<void> cancel(String sessionId);
}

abstract interface class DelayedScreenshotService {
  Future<RecordingSession> screenshotAfter(Duration delay);
}

/// Optional transport capability; the original recording API stays compatible.
abstract interface class LivestreamRecordingService {
  Future<RecordingSession> startLive(
    RecordingSettings settings, {
    required String serverUrl,
    required String streamKey,
  });
  Future<Map<String, dynamic>> currentLive();
  Stream<Map<String, dynamic>> get liveStates;
}

/// Optional credential storage, separate from capture and settings documents.
abstract interface class LivestreamDestinationStore {
  Future<Map<String, String>?> loadLiveDestination();
  Future<void> saveLiveDestination({
    required String name,
    required String serverUrl,
    required String streamKey,
  });
  Future<void> forgetLiveDestination();
}

/// Optional recording capability; existing recording adapters remain compatible.
abstract interface class RegionRecordingService {
  Future<({int width, int height})> captureDisplay();
  Future<RecordingSession> startRegion(
    RecordingSettings settings, {
    required int cropX,
    required int cropY,
    required int cropWidth,
    required int cropHeight,
  });
}

abstract interface class EditProjectRepository {
  Future<EditProject?> find(String id);
  Future<void> save(EditProject project);
  Future<void> delete(String id);
}

abstract interface class TrashRepository {
  Future<List<TrashEntry>> list();
  Future<TrashEntry> trash(MediaItem item);
  Future<MediaItem> restore(String id);
  Future<void> permanentlyDelete(String id);
}

abstract interface class BackgroundJobRepository {
  Future<List<BackgroundJob>> unfinished();
  Future<BackgroundJob?> find(String id);
  Future<void> save(BackgroundJob job);
  Stream<BackgroundJob> get changes;
  Future<void> cancel(String id);
}
