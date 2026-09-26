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
    this.hint,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.autofillHints,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final String? hint;
  final Widget? suffixIcon;

  /// Use more than 1 for descriptions and messages.
  final int maxLines;
  final int? minLines;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType ?? (multiline ? TextInputType.multiline : null),
      obscureText: obscureText,
      textInputAction: textInputAction ?? (multiline ? TextInputAction.newline : null),
      onChanged: onChanged,
      autocorrect: !obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      autofillHints: autofillHints,
      textCapitalization: multiline ? TextCapitalization.sentences : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        alignLabelWithHint: multiline,
      ),
    );
  }
}
