import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.ink),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!),
          ],
        ],
      ),
    );
  }
}
