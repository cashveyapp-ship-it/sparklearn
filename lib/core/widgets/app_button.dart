import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: isPrimary ? AppColors.indigo : Colors.white,
      foregroundColor: isPrimary ? Colors.white : AppColors.text,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      side: isPrimary ? null : const BorderSide(color: AppColors.border),
      minimumSize: fullWidth ? const Size.fromHeight(56) : null,
    );

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
      label: Text(label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      style: style,
    );
  }
}
