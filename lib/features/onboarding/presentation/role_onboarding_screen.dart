import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/form_message.dart';
import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';

/// Account setup, the same two questions the website asks: your name and what
/// you do. Saving creates the profile on the shared backend (the database adds
/// the account role), so the member can sign in on the website straight away.
class RoleOnboardingScreen extends ConsumerStatefulWidget {
  const RoleOnboardingScreen({required this.type, super.key});

  final AccountType type;

  @override
  ConsumerState<RoleOnboardingScreen> createState() => _RoleOnboardingScreenState();
}

class _RoleOnboardingScreenState extends ConsumerState<RoleOnboardingScreen> {
  final _name = TextEditingController();
  final _query = TextEditingController();
  RoleCategory? _category;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  static List<RoleCategory> categoriesFor(AccountType type) => switch (type) {
        AccountType.worker => jobCategories,
        AccountType.company => industries,
        AccountType.projectManager => specializations,
        AccountType.business => supplyCategories,
        AccountType.employer => clientNeeds,
      };

  static (String, String, String) copyFor(AccountType type) => switch (type) {
        AccountType.worker => ('Your name', 'Your trade', 'Choose your main trade. You can add more skills later.'),
        AccountType.company => ('Company name', 'Your industry', 'Choose the industry your company works in.'),
        AccountType.projectManager => ('Your name', 'Your specialization', 'Choose the kind of projects you manage.'),
        AccountType.business => ('Business name', 'What you supply', 'Choose your main product category.'),
        AccountType.employer => ('Your name', 'What you need done', 'Choose the trade you hire for most.'),
      };

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final (nameLabel, catTitle, catHelp) = copyFor(type);
    final q = _query.text.trim().toLowerCase();
    final all = categoriesFor(type);
    final list = q.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(q) || c.group.toLowerCase().contains(q)).toList();
    final muted = context.palette.textMuted;
    String? lastGroup;
    return Scaffold(
      appBar: AppBar(title: Text('${type.label} account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Set up your profile', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(type.summary, style: AppTextStyles.bodyMuted.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            key: const Key('setupName'),
            label: nameLabel,
            controller: _name,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(catTitle, style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.xxs),
          Text(catHelp, style: AppTextStyles.bodyMuted.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.sm),
          if (all.length > 8) ...[
            AppSearchField(controller: _query, hint: 'Search', onChanged: (_) => setState(() {})),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final c in list) ...[
            if (c.group.isNotEmpty && c.group != lastGroup && q.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxs),
                child: Text((lastGroup = c.group).toUpperCase(), style: AppTextStyles.bodyMuted.copyWith(color: muted, fontWeight: FontWeight.w700, letterSpacing: .8)),
              ),
            ],
            _CategoryTile(category: c, selected: _category?.id == c.id, onTap: () => setState(() => _category = c)),
          ],
          if (list.isEmpty) Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text('No matches', style: AppTextStyles.bodyMuted.copyWith(color: muted))),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            FormMessage(_error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Finish',
            isLoading: _saving,
            onPressed: _name.text.trim().length < 2 || _category == null ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).createRoleProfile(
            type: widget.type,
            name: _name.text.trim(),
            category: _category,
            phone: _e164(ref.read(pendingPhoneProvider)),
          );
      ref.invalidate(accountProfileProvider);
      await ref.read(accountProfileProvider.future);
      if (mounted) context.go(widget.type.homePath);
    } catch (error) {
      setState(() => _error = ErrorHandler.toAppException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 024 123 4567 → +233241234567 (how the website stores numbers on profiles).
  static String _e164(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    if (d.startsWith('233')) return '+$d';
    if (d.startsWith('0')) return '+233${d.substring(1)}';
    return '+233$d';
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  final RoleCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? p.text.withValues(alpha: .08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? p.text : p.line, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                      if (category.desc.isNotEmpty && category.group.isEmpty)
                        Text(category.desc, style: AppTextStyles.bodyMuted.copyWith(color: p.textMuted)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? p.text : p.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
