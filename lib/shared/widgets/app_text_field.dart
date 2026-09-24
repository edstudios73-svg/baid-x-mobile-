import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onChanged: onChanged,
      autocorrect: !obscureText,
      decoration: InputDecoration(labelText: label),
    );
  }
}
