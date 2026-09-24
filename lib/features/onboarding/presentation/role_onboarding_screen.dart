import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../account_type/domain/account_type.dart';

class RoleOnboardingScreen extends ConsumerStatefulWidget {
  const RoleOnboardingScreen({required this.type, super.key});

  final AccountType type;

  @override
  ConsumerState<RoleOnboardingScreen> createState() => _RoleOnboardingScreenState();
}

class _RoleOnboardingScreenState extends ConsumerState<RoleOnboardingScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _detail = TextEditingController();
  final _extra = TextEditingController();
  final _years = TextEditingController();
  final _availability = TextEditingController();
  final _summary = TextEditingController();
  final _phone = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _detail.dispose();
    _extra.dispose();
    _years.dispose();
    _availability.dispose();
    _summary.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return Scaffold(
      appBar: AppBar(title: Text('${type.label} setup')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text('Profile setup', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          _Step(label: 'Basic information', done: _name.text.trim().isNotEmpty),
          _Step(label: 'Professional or business information', done: _detail.text.trim().isNotEmpty),
          _Step(label: 'Location', done: _location.text.trim().isNotEmpty),
          const _Step(label: 'Profile photo — added later', done: false),
          const SizedBox(height: AppSpacing.lg),
          const CircleAvatar(radius: 28, child: Icon(Icons.person_outline)),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: _nameLabel(type),
            controller: _name,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Location',
            controller: _location,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: _detailLabel(type),
            controller: _detail,
            onChanged: (_) => setState(() {}),
          ),
          if (type == AccountType.worker) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Other skills, separated by commas', controller: _extra),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Years of experience',
              controller: _years,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Availability', controller: _availability),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Short professional description', controller: _summary),
          ],
          if (type == AccountType.business) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Short description', controller: _summary),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Phone',
              controller: _phone,
              keyboardType: TextInputType.phone,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: AppTextStyles.bodyMuted),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Save and continue',
            isLoading: _saving,
            onPressed: _save,
          ),
          TextButton(
            onPressed: _saving ? null : () => context.go(type.homePath),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  String _nameLabel(AccountType type) {
    return switch (type) {
      AccountType.business => 'Business name',
      AccountType.company => 'Company name',
      _ => 'Full name',
    };
  }

  String _detailLabel(AccountType type) {
    return switch (type) {
      AccountType.worker => 'Primary skill',
      AccountType.business => 'What you supply',
      AccountType.company => 'Company type',
      AccountType.projectManager => 'Professional title',
      AccountType.employer => 'Short description',
    };
  }

  Future<void> _save() async {
    final client = SupabaseConfig.client;
    final userId = ref.read(authStateProvider).asData?.value?.id;
    if (client == null || userId == null) {
      setState(() => _error = 'Sign in again to save this profile.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _write(client, userId);
      if (mounted) context.go(widget.type.homePath);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = ErrorHandler.toAppException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _write(SupabaseClient client, String userId) async {
    final type = widget.type;
    final name = _name.text.trim();
    final location = _location.text.trim();
    final detail = _detail.text.trim();
    final yearsText = _years.text.trim();
    final years = int.tryParse(yearsText);
    if (type == AccountType.worker && yearsText.isNotEmpty && (years == null || years < 0)) {
      throw const FormatException('Enter years of experience as a whole number.');
    }
    for (final skill in _extra.text.split(',')) {
      if (skill.trim().length > 80) {
        throw const FormatException('Keep each skill under 80 characters.');
      }
    }
    final profile = <String, dynamic>{};
    if (type != AccountType.business && type != AccountType.company && name.isNotEmpty) {
      profile['display_name'] = name;
    }
    if (location.isNotEmpty) profile['location_label'] = location;
    if (type == AccountType.employer || type == AccountType.projectManager) {
      if (detail.isNotEmpty) profile['headline'] = detail;
    }
    if (profile.isNotEmpty) {
      await client.from('profiles').update(profile).eq('id', userId);
    }
    switch (type) {
      case AccountType.worker:
        if (detail.isNotEmpty ||
            yearsText.isNotEmpty ||
            _availability.text.trim().isNotEmpty ||
            _summary.text.trim().isNotEmpty) {
          await client.from('worker_profiles').upsert({
            'profile_id': userId,
            'trade': detail,
            'summary': _summary.text.trim(),
            'availability': _availability.text.trim(),
            'years_experience': ?years,
          });
        }
        for (final skill in _extra.text.split(',')) {
          final trimmed = skill.trim();
          if (trimmed.isEmpty) continue;
          await client.from('worker_skills').upsert({
            'profile_id': userId,
            'skill_name': trimmed,
          }, onConflict: 'profile_id,skill_name');
        }
      case AccountType.business:
        if (name.isNotEmpty) {
          await client.from('business_profiles').upsert({
            'profile_id': userId,
            'business_name': name,
            'category': detail,
            'summary': _summary.text.trim(),
            'location_label': location,
          });
        }
        final phone = _phone.text.trim();
        if (phone.isNotEmpty) {
          await client.from('profile_private').update({
            'phone': phone,
          }).eq('profile_id', userId);
        }
      case AccountType.company:
        if (name.isNotEmpty) {
          final existing = await client
              .from('companies')
              .select('id')
              .eq('owner_profile_id', userId)
              .limit(1)
              .maybeSingle();
          final values = {'name': name, 'industry': detail};
          if (existing == null) {
            await client.from('companies').insert({
              'owner_profile_id': userId,
              ...values,
            });
          } else {
            await client.from('companies').update(values).eq('id', existing['id']);
          }
        }
      case AccountType.employer:
      case AccountType.projectManager:
        break;
    }
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: done ? AppColors.ink : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
        ],
      ),
    );
  }
}
