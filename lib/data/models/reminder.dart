import 'package:flutter/material.dart';

class Reminder {
  const Reminder({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.sentByMe,
    required this.color,
  });

  final String title;
  final String message;
  final String time;
  final IconData icon;
  final bool sentByMe;
  final Color color;
}
