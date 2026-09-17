import 'package:flutter/material.dart';

/// Centralized icon tokens and consistent sizing for Study Vault.
class AppIcons {
  AppIcons._();

  // Standard Icon Sizes
  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;

  // Primary Navigation Icons
  static const IconData home = Icons.home_outlined;
  static const IconData homeActive = Icons.home_rounded;

  static const IconData subjects = Icons.auto_stories_outlined;
  static const IconData subjectsActive = Icons.auto_stories_rounded;

  static const IconData inbox = Icons.inbox_outlined;
  static const IconData inboxActive = Icons.inbox_rounded;

  static const IconData vault = Icons.folder_copy_outlined;
  static const IconData vaultActive = Icons.folder_copy_rounded;

  static const IconData shared = Icons.group_outlined;
  static const IconData sharedActive = Icons.group_rounded;

  static const IconData profile = Icons.person_outline_rounded;
  static const IconData profileActive = Icons.person_rounded;

  // Primary Action Icons
  static const IconData search = Icons.search_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData filter = Icons.filter_list_rounded;
  static const IconData sort = Icons.swap_vert_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData moreVertical = Icons.more_vert_rounded;
  static const IconData share = Icons.share_outlined;
  static const IconData download = Icons.download_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_rounded;

  // Content & File Type Icons
  static const IconData folder = Icons.folder_rounded;
  static const IconData document = Icons.description_outlined;
  static const IconData note = Icons.sticky_note_2_outlined;
  static const IconData pdf = Icons.picture_as_pdf_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData audio = Icons.mic_none_rounded;
  static const IconData camera = Icons.camera_alt_outlined;

  // Feedback & Status Icons
  static const IconData error = Icons.error_outline_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData success = Icons.check_circle_outline_rounded;

  // Form Field Icons
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeOff = Icons.visibility_off_outlined;
  static const IconData email = Icons.mail_outline_rounded;
  static const IconData lock = Icons.lock_outline_rounded;
}
