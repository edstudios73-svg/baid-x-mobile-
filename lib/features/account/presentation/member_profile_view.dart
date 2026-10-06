import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/member_ui.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../account_type/domain/account_type.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/account_setup.dart';
import 'account_sheets.dart';

/// The member account screen from the website (`#profileMember`, `.acc2`):
/// cover and avatar, name with seal, the verified card or the checklist card,
/// the role menu, account rows, info rows and sign out.
class MemberProfileView extends ConsumerWidget {
  const MemberProfileView({required this.me, super.key});
  final AccountProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = me.type!;
    final p = me.row;
    final cl = checklistState(type, p);
    final (photoCol, _, _) = photoOf(type);
    final photo = p[photoCol] as String?;
    final cover = p['cover_url'] as String?;
    final verified = me.isVerified;
    final tier = verified ? (me.badgeTier ?? 'verified') : null;
    final phone = me.phone;
    final shownPhone = phone.isEmpty ? '' : (RegExp(r'^\d').hasMatch(phone) ? '+$phone' : phone);

    void step(String title) {
      final i = checklists[type]!.indexWhere((c) => c.title == title);
      context.push(i < 0 ? AppRoutes.checklist : '${AppRoutes.checklist}/step/$i');
    }

    final menu = <(String, String, VoidCallback)>[
      ('Plans & billing', 'Your plan, payments and receipts.', () => context.push(AppRoutes.billing)),
      ('Organizations', 'Teams, people, roles and access.', () => context.push(AppRoutes.orgs)),
      ...switch (type) {
        AccountType.worker => [
            ('Edit profile', 'Update profile details.', () => context.push(AppRoutes.checklist)),
            ('Wallet', 'Earnings, balance and withdrawals.', () => context.push(AppRoutes.wallet)),
            ('Materials', 'Building materials from suppliers.', () => context.push(AppRoutes.materials)),
            ('Equipment', 'Rent or buy machines and tools.', () => context.push(AppRoutes.equipment)),
            ('Career growth', 'Experience, level and certifications.', () => context.push(AppRoutes.growth)),
            ('Portfolio', 'Add completed works with images and descriptions.', () => context.push(AppRoutes.portfolio)),
            ('Certifications', 'Upload trade certificates and licences.', () => context.push(AppRoutes.certs)),
            ('Verification documents', 'Verify your identity.', () => step('Ghana Card')),
          ],
        AccountType.company => [
            ('Edit company profile', 'Update company details.', () => context.push(AppRoutes.checklist)),
            ('Wallet', 'Add money, earnings and withdrawals.', () => context.push(AppRoutes.wallet)),
            ('Payments', 'Worker payments and records.', () => context.push(AppRoutes.payments)),
            ('Equipment', 'Find and request equipment.', () => context.push(AppRoutes.equipment)),
            ('Materials', 'Find and compare materials.', () => context.push(AppRoutes.materials)),
            ('My orders', 'Track what you have ordered.', () => context.push(AppRoutes.orders)),
            ('Job posts', 'Post jobs and manage applicants.', () => context.go(AppRoutes.myJobs)),
            ('Team & join code', 'Link a project manager to your company.', () => context.push(AppRoutes.teamLink)),
            ('Verification documents', 'Verify your company.', () => step('Registration documents')),
          ],
        AccountType.projectManager => [
            ('Edit profile', 'Update profile details.', () => context.push(AppRoutes.checklist)),
            ('Wallet', 'Earnings, balance and withdrawals.', () => context.push(AppRoutes.wallet)),
            ('Materials', 'Building materials from suppliers.', () => context.push(AppRoutes.materials)),
            ('Equipment', 'Rent or buy machines and tools.', () => context.push(AppRoutes.equipment)),
            ('Past projects', 'Show projects you have delivered.', () => context.push(AppRoutes.portfolio)),
            ('Certifications', 'Add your project management certificates.', () => context.push(AppRoutes.certs)),
            ('Link a company', 'Join a company with its code.', () => context.push(AppRoutes.teamLink)),
            ('Verification documents', 'Verify your identity.', () => step('Ghana Card')),
          ],
        AccountType.business => [
            ('Edit business profile', 'Update business details.', () => context.push(AppRoutes.checklist)),
            ('Wallet', 'Earnings, balance and withdrawals.', () => context.push(AppRoutes.wallet)),
            ('Orders', 'Orders from buyers, paid through escrow.', () => context.push(AppRoutes.orders)),
            ('Catalog', 'Manage products and equipment.', () => context.go(AppRoutes.listings)),
            ('Portfolio', 'Show your products and past supply.', () => context.push(AppRoutes.portfolio)),
            ('Verification documents', 'Verify your business.', () => step('Registration documents')),
          ],
        AccountType.employer => [
            ('Edit profile', 'Update profile details.', () => context.push(AppRoutes.checklist)),
            ('Wallet', 'Add money and pay for work.', () => context.push(AppRoutes.wallet)),
            ('Post a job', 'Hire a professional for your home.', () => context.push(AppRoutes.postJob)),
            ('Job posts', 'Post jobs and see who applied.', () => context.go(AppRoutes.myJobs)),
            ('Equipment', 'Rent or buy equipment from suppliers.', () => context.push(AppRoutes.equipment)),
            ('Materials', 'Buy materials from suppliers.', () => context.push(AppRoutes.materials)),
            ('My orders', 'Track what you have ordered.', () => context.push(AppRoutes.orders)),
            ('Verification documents', 'Verify your identity.', () => context.push(AppRoutes.checklist)),
          ],
      },
    ];

    Future<void> web(String page) => launchUrl(Uri.parse('${AppConfig.webBase}/$page'), mode: LaunchMode.externalApplication);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: () async => ref.invalidate(accountProfileProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              MemberAppBar(name: me.displayName, photo: photo),
              const SizedBox(height: 12),
              _Header(name: me.displayName.isEmpty ? 'Your account' : me.displayName, photo: photo, cover: cover, phone: shownPhone, tier: tier, role: '${type.label} account', status: verified ? (VerifiedBadge.labels[tier] ?? 'Verified') : statusLabel(p['verification_status']), statusColor: verified ? VerifiedBadge.colorOf(tier) : null),
              const SizedBox(height: 10),
              if (verified) _VerifiedCard(tier: tier!, role: type.label) else _ChecklistCard(done: cl.done, total: cl.total),
              const SizedBox(height: 10),
              _Rows([for (final m in menu) (m.$1, m.$2, m.$3)]),
              const SizedBox(height: 10),
              _Rows([
                ('Add email', 'Add your own email address. None is set for you.', () => openAddEmail(context, type: type)),
                ('Change phone', 'Update the mobile number linked to this account.', () => openChangePhone(context)),
                ('Switch account', 'Use another account on this device.', () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go(AppRoutes.signIn);
                }),
                ('Change password', 'Set a new password for sign-in.', () => openChangePassword(context)),
              ]),
              const SizedBox(height: 10),
              _Rows([
                ('User guide', 'How to use BAID X, step by step, for every role.', () => web('docs.html')),
                ('Terms of service', 'Read our service terms.', () => web('terms.html')),
                ('Privacy policy', 'Read how we handle your information.', () => web('privacy.html')),
                ('About BAID X', 'Product and company information.', () => web('about.html')),
              ]),
              const SizedBox(height: 10),
              _LogOut(onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go(AppRoutes.discover);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.photo, required this.cover, required this.phone, required this.tier, required this.role, required this.status, this.statusColor});
  final String name, phone, role, status;
  final String? photo, cover, tier;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // cover with the avatar overlapping its bottom edge
          SizedBox(
            height: 150,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                bottom: 40,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: cover != null && cover!.isNotEmpty
                      ? Image.network(cover!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _CoverArt())
                      : const _CoverArt(),
                ),
              ),
              Positioned(
                left: 18,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(24)),
                  child: InitialsAvatar(name: name, photoUrl: photo, size: 78, radius: 21),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.4))),
                if (tier != null) ...[const SizedBox(width: 6), VerifiedBadge(tier, size: 19)],
              ]),
              if (phone.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(phone, style: TextStyle(fontSize: 13, color: AppColors.muted))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                Pill(role),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (statusColor ?? Colors.white).withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (statusColor ?? Colors.white).withValues(alpha: statusColor == null ? .14 : .4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (statusColor != null) ...[Icon(Icons.verified, size: 13, color: statusColor), const SizedBox(width: 4)],
                    Text(status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor ?? AppColors.textLight)),
                  ]),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1C1C1C), Color(0xFF0A0A0A)]),
        ),
        child: const SizedBox.expand(),
      );
}

class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.tier, required this.role});
  final String tier, role;

  static const _subs = {
    'verified': 'Reviewed by the BAID X team',
    'identity': 'Ghana Card checked against the owner',
    'professional': 'Trade skills and work history checked',
    'advanced': 'Identity, skills and references checked',
  };

  @override
  Widget build(BuildContext context) {
    final c = VerifiedBadge.colorOf(tier);
    return SurfaceCard(
      borderColor: c.withValues(alpha: .35),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.verified, color: c, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${VerifiedBadge.labels[tier] ?? 'Verified'} ${role.toLowerCase()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${_subs[tier] ?? _subs['verified']}. The badge shows on your profile and cards.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.done, required this.total});
  final int done, total;

  @override
  Widget build(BuildContext context) {
    return DashedCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      onTap: () => context.push(AppRoutes.checklist),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2A2A)),
          child: const Icon(Icons.check_circle_outline_rounded, size: 20, color: Color(0xFFD6D6D6)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Verification checklist', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            SizedBox(height: 2),
            Text('Complete required checks before your profile can be approved.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
          child: Text('$done/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
      ]),
    );
  }
}

class _LogOut extends StatelessWidget {
  const _LogOut({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: onTap,
      child: const Row(children: [
        Icon(Icons.logout_rounded, size: 20, color: AppColors.red),
        SizedBox(width: 12),
        Text('Log out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppColors.red)),
      ]),
    );
  }
}

/// A grouped list of `.acc-row` buttons.
class _Rows extends StatelessWidget {
  const _Rows(this.rows);
  final List<(String, String, VoidCallback)> rows;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.lineGlass, indent: 16, endIndent: 16),
          InkWell(
            onTap: rows[i].$3,
            borderRadius: BorderRadius.vertical(top: Radius.circular(i == 0 ? 20 : 0), bottom: Radius.circular(i == rows.length - 1 ? 20 : 0)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(rows[i].$2, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
