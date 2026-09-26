import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../domain/account_type.dart';

class AccountTypeScreen extends ConsumerStatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  ConsumerState<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends ConsumerState<AccountTypeScreen> {
  AccountType? _selected;
  var _confirming = false;

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final error = action.hasError ? action.error : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_confirming ? 'Confirm' : 'Account type'),
      ),
      body: SafeArea(
        child: _confirming ? _confirm(action.isLoading, error) : _choose(),
      ),
    );
  }

  Widget _choose() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text('How will you use BAID X?', style: AppTextStyles.headline),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Choose the account type that best matches what you do.',
          style: AppTextStyles.bodyMuted,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final type in AccountType.values) ...[
          _RoleOption(
            type: type,
            selected: _selected == type,
            onTap: () => setState(() => _selected = type),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Continue',
          onPressed: _selected == null ? null : () => setState(() => _confirming = true),
        ),
      ],
    );
  }

  Widget _confirm(bool loading, Object? error) {
    final type = _selected!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You selected ${type.label}.', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your account will be set up for ${type.label.toLowerCase()}. You can continue to complete your profile.',
            style: AppTextStyles.body,
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              error is AppException ? error.message : 'Couldn\'t save the account type.',
              style: AppTextStyles.bodyMuted,
            ),
          ],
          const Spacer(),
          AppButton(
            label: 'Back',
            outlined: true,
            onPressed: loading ? null : () => setState(() => _confirming = false),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Continue',
            isLoading: loading,
            onPressed: () => _save(type),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AccountType type) async {
    final ok = await ref.read(authActionProvider.notifier).run(() async {
      await ref.read(authRepositoryProvider).setAccountType(type.dbValue);
      ref.invalidate(accountProfileProvider);
      final profile = await ref.read(accountProfileProvider.future);
      if (profile?.accountType != type.dbValue) {
        throw const AuthFlowException(
          'BAID X did not confirm this account type. Try again.',
        );
      }
    });
    if (ok && mounted) context.go(type.setupPath);
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AccountType type;
  final bool selected;
  final VoidCallback onTap;

  IconData _roleIcon(AccountType type) {
    return switch (type) {
      AccountType.worker => Icons.handyman_outlined,
      AccountType.employer => Icons.person_search_outlined,
      AccountType.business => Icons.storefront_outlined,
      AccountType.projectManager => Icons.account_tree_outlined,
      AccountType.company => Icons.apartment_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.yellow.withValues(alpha: 0.14) : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: selected ? AppColors.ink : palette.line, width: selected ? 1.6 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.yellow : palette.subtle,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(_roleIcon(type), color: selected ? AppColors.ink : palette.textMuted),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label, style: AppTextStyles.label.copyWith(color: palette.text, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(type.summary, style: AppTextStyles.caption.copyWith(color: palette.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppColors.ink : palette.line,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
