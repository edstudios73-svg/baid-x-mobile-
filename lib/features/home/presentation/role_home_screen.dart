import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../account_type/domain/account_type.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({required this.type, super.key});

  final AccountType type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(type.label)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${type.label} home', style: AppTextStyles.display),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Coming in Phase 5. Your account type is saved in BAID X.',
              style: AppTextStyles.body,
            ),
            const Spacer(),
            AppButton(
              label: 'Finish profile',
              outlined: true,
              onPressed: () => context.push(type.setupPath),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Browse marketplace',
              onPressed: () => context.go(AppRoutes.marketplace),
            ),
          ],
        ),
      ),
    );
  }
}
