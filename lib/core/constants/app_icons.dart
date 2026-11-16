import 'package:flutter/widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Semantic names keep package glyphs out of screens and allow icon tree shaking.
///
/// Iconsax linear glyphs (the package's `_copy` variants; plain names are the
/// bold set) give the app soft, rounded glyphs with generous corner
/// radii instead of sharp geometric outlines.
@staticIconProvider
abstract final class AppIcons {
  static const video = Iconsax.video_copy;
  static const pictureInPicture = Iconsax.screenmirroring_copy;
  static const videos = Iconsax.video_play_copy;
  static const photos = Iconsax.gallery_copy;
  static const image = Iconsax.image_copy;
  static const imageUnavailable = Iconsax.gallery_slash_copy;
  static const edit = Iconsax.magicpen_copy;
  static const photoEdit = Iconsax.gallery_edit_copy;
  static const pen = Iconsax.edit_2_copy;
  static const shapes = Iconsax.shapes_copy;
  static const sticker = Iconsax.sticker_copy;
  static const text = Iconsax.text_copy;
  static const eraser = Iconsax.eraser_copy;
  static const palette = Iconsax.color_swatch_copy;
  static const crop = Iconsax.crop_copy;
  static const flipHorizontal = Iconsax.arrow_swap_horizontal_copy;
  static const flipVertical = Iconsax.arrow_swap_copy;
  static const newProject = Iconsax.additem_copy;
  static const settings = Iconsax.setting_4_copy;

  // Bold glyphs mark the selected navigation tab.
  static const videosActive = Iconsax.video_play;
  static const photosActive = Iconsax.gallery;
  static const editActive = Iconsax.magicpen;
  static const settingsActive = Iconsax.setting_4;

  static const videoSettings = Iconsax.setting_2_copy;
  static const create = Iconsax.add_copy;
  static const close = Iconsax.close_circle_copy;
  static const back = Iconsax.arrow_left_2_copy;
  static const forward = Iconsax.arrow_right_1_copy;
  static const chevronRight = Iconsax.arrow_right_3_copy;
  static const chevronDown = Iconsax.arrow_down_1_copy;
  static const chevronUp = Iconsax.arrow_up_2_copy;
  static const open = Iconsax.export_3_copy;
  static const more = Iconsax.more_copy;
  static const search = Iconsax.search_normal_1_copy;
  static const tools = Iconsax.category_copy;
  static const record = Iconsax.record_circle_copy;
  static const pause = Iconsax.pause_copy;
  static const play = Iconsax.play_copy;
  static const stop = Iconsax.stop_copy;
  static const ready = Iconsax.verify_copy;
  static const processing = Iconsax.timer_copy;
  static const error = Iconsax.warning_2_copy;
  static const screenshot = Iconsax.camera_copy;
  static const warning = Iconsax.danger_copy;
  static const facecam = Iconsax.profile_circle_copy;
  static const region = Iconsax.scan_copy;
  static const countdown = Iconsax.timer_1_copy;
  static const livestream = Iconsax.airdrop_copy;
  static const captions = Iconsax.subtitle_copy;
  static const microphone = Iconsax.microphone_2_copy;
  static const export = Iconsax.export_1_copy;
  static const save = Iconsax.save_2_copy;
  static const undo = Iconsax.undo_copy;
  static const redo = Iconsax.redo_copy;
  static const split = Iconsax.scissor_copy;
  static const rotate = Iconsax.rotate_left_copy;
  static const moveEarlier = Iconsax.arrow_up_3_copy;
  static const moveLater = Iconsax.arrow_down_copy;
  static const share = Iconsax.share_copy;
  static const rename = Iconsax.edit_2_copy;
  static const trash = Iconsax.trash_copy;
  static const deleteForever = Iconsax.minus_cirlce_copy;
  static const restore = Iconsax.refresh_left_square_copy;
  static const reset = Iconsax.rotate_left_copy;
  static const refresh = Iconsax.refresh_copy;
  static const sort = Iconsax.sort_copy;
  static const sortNewest = Iconsax.calendar_1_copy;
  static const sortOldest = Iconsax.calendar_2_copy;
  static const sortName = Iconsax.text_block_copy;
  static const sortSize = Iconsax.weight_copy;
  static const sortDuration = Iconsax.clock_copy;
  static const storage = Iconsax.driver_copy;
  static const folder = Iconsax.folder_copy;
  static const folderOpen = Iconsax.folder_open_copy;
  static const folderUnavailable = Iconsax.folder_cross_copy;
  static const help = Iconsax.message_question_copy;
  static const feedback = Iconsax.message_copy;
  static const privacy = Iconsax.shield_tick_copy;
  static const showSecret = Iconsax.eye_copy;
  static const hideSecret = Iconsax.eye_slash_copy;
  static const info = Iconsax.info_circle_copy;
  static const attachment = Iconsax.paperclip_2_copy;
  static const selected = Iconsax.tick_circle_copy;
  static const check = Iconsax.check_copy;
  static const unselected = Iconsax.record_copy;
}
