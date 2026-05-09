import 'package:flutter/material.dart';

import 'primary_pill_button.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PrimaryPillButton(
        label: label,
        icon: icon,
        onPressed: onPressed,
        isLoading: isLoading,
      ),
    );
  }
}
