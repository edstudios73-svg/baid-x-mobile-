import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_empty_state.dart';

class FoundationPlaceholderScreen extends StatelessWidget {
  const FoundationPlaceholderScreen({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppEmptyState(title: title, message: message),
        ],
      ),
    );
  }
}
