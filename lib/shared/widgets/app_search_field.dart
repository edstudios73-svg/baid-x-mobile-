import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Single-line search input with a leading icon. Styling comes from the input theme.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.icon = Icons.search,
    this.keyboardType,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: context.palette.textMuted),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        isDense: true,
      ),
    );
  }
}
