import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum ReminderType { gentle, strict, encourage, praise }

class Reminder {
  const Reminder({
    required this.id,
    required this.type,
    required this.content,
    required this.fromUserId,
    required this.toUserId,
    this.planId,
    this.isRead = false,
    this.sentByMe = false,
    required this.createdAt,
  });

  final String id;
  final ReminderType type;
  final String content;
  final String fromUserId;
  final String toUserId;
  final String? planId;
  final bool isRead;
  final bool sentByMe;
  final DateTime createdAt;
}

extension ReminderDisplay on ReminderType {
  String get label => switch (this) {
    ReminderType.gentle => '温柔提醒',
    ReminderType.strict => '认真监督',
    ReminderType.encourage => '鼓励一下',
    ReminderType.praise => '夸夸对方',
  };

  IconData get icon => switch (this) {
    ReminderType.gentle => Icons.alarm_rounded,
    ReminderType.strict => Icons.assignment_turned_in_rounded,
    ReminderType.encourage => Icons.thumb_up_alt_rounded,
    ReminderType.praise => Icons.favorite_rounded,
  };

  Color get color => switch (this) {
    ReminderType.gentle => AppColors.reminder,
    ReminderType.strict => AppColors.primary,
    ReminderType.encourage => AppColors.success,
    ReminderType.praise => AppColors.primary,
  };
}
