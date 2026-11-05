import 'package:flutter/services.dart';

import '../domain/models.dart';

enum NoticeKind { success, error, warning, info, loading }

enum UserOperation {
  recording,
  screenshot,
  captureControl,
  loadLibrary,
  openMedia,
  chooseFolder,
  storage,
  loadDrafts,
  loadTrash,
  editClip,
  createDraft,
  saveDraft,
  deleteDraft,
  preview,
  export,
  loadPhoto,
  savePhoto,
  share,
  rename,
  trash,
  restore,
  deleteMedia,
  support,
}

class UserNotice {
  const UserNotice(this.text, {this.kind = NoticeKind.error, this.helpTopic});
  final String text;
  final NoticeKind kind;
  final String? helpTopic;
}

/// Only reviewed copy crosses the UI boundary. Native messages stay diagnostic.
abstract final class UserMessages {
  static UserNotice failure(Object? error, {required UserOperation operation}) {
    final code = switch (error) {
      DomainFailure e => e.code.name,
      PlatformException e => e.code,
      MissingPluginException() => 'unavailable',
      _ => '',
    };
    final detail = switch (error) {
      DomainFailure e => e.message,
      PlatformException e => e.message ?? '',
      _ => error?.toString() ?? '',
    }.toLowerCase();
    final capture =
        operation == UserOperation.recording ||
        operation == UserOperation.screenshot ||
        operation == UserOperation.captureControl;
    if (code == 'cancelled') {
      return const UserNotice('Cancelled.', kind: NoticeKind.info);
    }
    if (code == 'revoked') {
      return const UserNotice(
        'Folder access changed. Choose the folder again.',
      );
    }
    if (code == 'denied' ||
        detail.contains('permission denied') ||
        detail.contains('permission was denied')) {
      return UserNotice(
        capture
            ? (operation == UserOperation.screenshot
                  ? "Screenshot permission wasn't granted."
                  : "Screen recording permission wasn't granted.")
            : "Access wasn't granted. Choose the file or folder again.",
      );
    }
    if (code == 'missing') {
      return const UserNotice(
        'This file is no longer available. Choose another file.',
      );
    }
    if (detail.contains('storage') ||
        detail.contains('no space') ||
        detail.contains('disk full')) {
      return const UserNotice(
        "Couldn't save the file. Free some storage and try again.",
      );
    }
    if (capture && detail.contains('protected')) {
      return const UserNotice(
        'Protected screens may block capture.',
        kind: NoticeKind.warning,
        helpTopic: 'protected-capture',
      );
    }
    if (capture &&
        (detail.contains('interrupted') || detail.contains('unexpectedly'))) {
      return const UserNotice(
        'Recording stopped unexpectedly. See Help & Guides.',
        helpTopic: 'recording-stopped',
      );
    }
    if (capture && (code == 'busy' || detail.contains('active session'))) {
      return const UserNotice(
        'Finish the current recording first.',
        kind: NoticeKind.warning,
      );
    }
    if (capture && detail.contains('stop')) {
      return const UserNotice("Couldn't stop recording. Try again.");
    }
    if (capture && detail.contains('pause')) {
      return const UserNotice("Couldn't pause recording. Try again.");
    }
    if (capture && detail.contains('resume')) {
      return const UserNotice("Couldn't resume recording. Try again.");
    }
    if (code == 'unavailable') {
      return const UserNotice(
        "This action isn't available right now. Try again.",
      );
    }
    if (code == 'invalid' && operation == UserOperation.rename) {
      return const UserNotice('Use a valid filename and try again.');
    }
    if (operation == UserOperation.editClip && detail.contains('playhead')) {
      return const UserNotice(
        'Place the playhead inside the clip to split it.',
      );
    }
    return UserNotice(switch (operation) {
      UserOperation.recording =>
        "Couldn't record your screen. Check permissions and try again.",
      UserOperation.screenshot => "Couldn't save the screenshot. Check permissions and storage, then try again.",
      UserOperation.captureControl =>
        "Couldn't update the recording. Try again.",
      UserOperation.loadLibrary =>
        "Couldn't load your media. Try again or choose a folder.",
      UserOperation.openMedia =>
        "Couldn't open this file. Check access and try again.",
      UserOperation.chooseFolder =>
        "Couldn't open this folder. Choose it again.",
      UserOperation.storage => "Couldn't check storage. Try again.",
      UserOperation.loadDrafts => "Couldn't load your drafts. Try again.",
      UserOperation.loadTrash => "Couldn't load Trash. Try again.",
      UserOperation.editClip =>
        "Couldn't apply this edit. Check the clip and try again.",
      UserOperation.createDraft =>
        "Couldn't create a project. Check storage and try again.",
      UserOperation.saveDraft =>
        "Couldn't save your draft. Check storage and try again.",
      UserOperation.deleteDraft => "Couldn't delete this draft. Try again.",
      UserOperation.preview =>
        "Couldn't play this video. Check access or choose another file.",
      UserOperation.export =>
        "Couldn't export this video. Check storage and try again.",
      UserOperation.loadPhoto =>
        "Couldn't open this photo. Check access or choose another file.",
      UserOperation.savePhoto =>
        "Couldn't save the photo. Check storage and try again.",
      UserOperation.share =>
        "Couldn't open sharing. Check the file and try again.",
      UserOperation.rename =>
        "Couldn't rename this file. Check the name and try again.",
      UserOperation.trash => "Couldn't move this file to Trash. Try again.",
      UserOperation.restore =>
        "Couldn't restore this file. Check storage and try again.",
      UserOperation.deleteMedia => "Couldn't delete this file. Try again.",
      UserOperation.support =>
        "Couldn't prepare your report. Check the attachment and try again.",
    });
  }
}
