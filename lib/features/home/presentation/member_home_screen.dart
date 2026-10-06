import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/member_ui.dart';
import '../../account/data/account_actions.dart';
import '../../account/domain/account_setup.dart';
import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';
import '../../hiring/build_screen.dart';
import '../../workspace/data/workspace_data.dart';
import '../../workspace/presentation/home_inbox.dart';
import '../../account/presentation/extra_screens.dart' show notificationsProvider;

/// Numbers for the member Home (website js/dash.js HOME[role]); null means
/// "couldn't load" and shows as a dash, never a made-up figure.
class HomeStats {
  const HomeStats(this.a, this.b, this.c, {this.extra = const {}});
  final int? a, b, c;
  final Map<String, Object?> extra;
}

final homeStatsProvider = FutureProvider.family<HomeStats, AccountType>((ref, type) async {
  final me = await ref.watch(accountProfileProvider.future);
  final uid = me?.id;
  if (uid == null) return const HomeStats(null, null, null);
  final a = AccountActions();
  switch (type) {
    case AccountType.worker:
      final r = await Future.wait([
        a.count('jobs', (q) => q.eq('status', 'open')),
        a.count('job_applications', (q) => q.eq('worker_id', uid)),
        a.count('job_applications', (q) => q.eq('worker_id', uid).eq('status', 'accepted')),
      ]);
      final w = await a.rows('wallet_accounts', 'available_ghs', (q) => q.eq('owner_id', uid).limit(1));
      return HomeStats(r[0], r[1], r[2], extra: {'wallet': w.isEmpty ? 0 : w.first['available_ghs']});
    case AccountType.company:
      final projects = await a.rows('projects', 'id,name,status,progress_pct,city_town', (q) => q.eq('company_id', uid).order('created_at', ascending: false).limit(5));
      final jobs = await a.rows('jobs', 'id,status', (q) => q.eq('company_id', uid).limit(200));
      final ids = [for (final j in jobs) j['id']];
      final applicants = ids.isEmpty ? 0 : await a.count('job_applications', (q) => q.inFilter('job_id', ids));
      final active = projects.where((p) => ['active', 'planning'].contains('${p['status']}'.toLowerCase())).length;
      return HomeStats(active, jobs.where((j) => j['status'] == 'open').length, applicants, extra: {'project': projects.isEmpty ? null : projects.first});
    case AccountType.projectManager:
      final projects = await a.rows('projects', 'id,name,status,progress_pct,city_town', (q) => q.eq('pm_id', uid).order('created_at', ascending: false).limit(10));
      final ids = [for (final p in projects) p['id']];
      final open = ids.isEmpty ? 0 : await a.count('project_tasks', (q) => q.inFilter('project_id', ids).neq('status', 'done'));
      final avg = projects.isEmpty ? 0 : (projects.map((p) => num.tryParse('${p['progress_pct'] ?? 0}') ?? 0).reduce((x, y) => x + y) / projects.length).round();
      return HomeStats(projects.length, open, avg, extra: {'project': projects.isEmpty ? null : projects.first});
    case AccountType.business:
      final r = await Future.wait([
        a.count('business_products', (q) => q.eq('business_id', uid)),
        a.count('business_equipment', (q) => q.eq('business_id', uid)),
        a.count('product_inquiries', (q) => q.eq('business_id', uid)),
      ]);
      final latest = await a.rows('product_inquiries', 'id,inquirer_name,message,created_at', (q) => q.eq('business_id', uid).order('created_at', ascending: false).limit(1));
      return HomeStats(r[0], r[1], r[2], extra: {'inquiry': latest.isEmpty ? null : latest.first});
    case AccountType.employer:
      final jobs = await a.rows('jobs', 'id,status', (q) => q.eq('employer_id', uid).limit(200));
      final ids = [for (final j in jobs) j['id']];
      final hired = ids.isEmpty ? 0 : await a.count('job_applications', (q) => q.inFilter('job_id', ids).eq('status', 'accepted'));
      return HomeStats(jobs.length, jobs.where((j) => j['status'] == 'open').length, hired);
  }
});

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(accountProfileProvider).asData?.value;
    final type = me?.type;
    if (me == null || type == null) return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    final stats = ref.watch(homeStatsProvider(type)).asData?.value;
    final p = me.row;
    final cl = checklistState(type, p);
    final (photoCol, _, _) = photoOf(type);
    String n(int? v) => v == null ? '—' : '$v';
    final verified = me.isVerified;
    final badge = verified ? (me.badgeTier ?? 'verified') : null;
    final first = me.displayName.trim().split(RegExp(r'\s+')).first;
    final place = [p['city_town'], p['region']].where(real).join(', ');

    final body = <Widget>[
      MemberAppBar(name: me.displayName, photo: p[photoCol] as String?),
    ];
    switch (type) {
      case AccountType.worker:
        final trade = jobCategories.where((c) => c.id == p['primary_job_category_id']).map((c) => c.name).firstOrNull ?? 'Professional';
        final xp = (p['xp_total'] as num?)?.toInt() ?? 0;
        final rank = _pretty(p['rank_tier']).isEmpty ? 'New' : _pretty(p['rank_tier']);
        body.addAll([
          GreetingHero(title: first.isEmpty ? 'Welcome' : first, subtitle: '$trade · ${place.isEmpty ? 'Add your location' : place}', badge: badge, chips: [if (p['available_for_work'] == true) '● Available for work', '$rank · $xp XP']),
          if (!verified && cl.done < cl.total) SetupBanner(done: cl.done, total: cl.total),
          StatRow([(n(stats?.a), 'Open jobs', Icons.work_outline), (n(stats?.b), 'Applications', Icons.mail_outline), (n(stats?.c), 'Accepted', Icons.task_alt)]),
          DashCard(
            title: rank == 'New' ? 'New worker' : rank,
            right: '$xp XP',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GlowBar(xp / 2000),
              const SizedBox(height: 10),
              Text('Earn XP by finishing your profile, getting accepted and completing jobs.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const SectionLabel('Quick access'),
          QuickTiles([
            (Icons.account_balance_wallet_outlined, 'Wallet', 'GH₵${(num.tryParse('${stats?.extra['wallet'] ?? 0}') ?? 0).toStringAsFixed(2)}', () => context.push(AppRoutes.wallet)),
            (Icons.trending_up, 'Career growth', '$xp XP', () => context.push(AppRoutes.growth)),
            (Icons.work_outline, 'Applications', '${n(stats?.b)} total', () => context.go(AppRoutes.applications)),
            (Icons.star_border_rounded, 'Trust score', (num.tryParse('${p['trust_score'] ?? 0}') ?? 0).toStringAsFixed(1), () => context.push(AppRoutes.growth)),
          ]),
        ]);
      case AccountType.company:
        final pr = stats?.extra['project'] as Map?;
        body.addAll([
          GreetingHero(title: me.displayName.isEmpty ? 'Your company' : me.displayName, subtitle: 'Here\'s how your projects and hiring are doing.', badge: badge),
          if (!verified && cl.done < cl.total) SetupBanner(done: cl.done, total: cl.total),
          StatRow([(n(stats?.a), 'Active projects', Icons.folder_outlined), (n(stats?.b), 'Open jobs', Icons.work_outline), (n(stats?.c), 'Applicants', Icons.groups_outlined)]),
          _projectCard(context, pr, emptyTitle: 'Start your first project', emptyText: 'Define the workers, project manager, equipment and materials you need, then invite people in.', cta: ('Create a project', () => context.push(AppRoutes.createProject))),
          const SectionLabel('Run the business'),
          QuickTiles([
            (Icons.payments_outlined, 'Payments', 'Records and invoices', () => context.push(AppRoutes.payments)),
            (Icons.construction_outlined, 'Equipment', 'Find and request', () => context.push(AppRoutes.equipment)),
            (Icons.inventory_2_outlined, 'Materials', 'Compare supply', () => context.push(AppRoutes.materials)),
            (Icons.key_outlined, 'Join code', 'Link a project manager', () => context.push(AppRoutes.teamLink)),
          ]),
        ]);
      case AccountType.projectManager:
        final pr = stats?.extra['project'] as Map?;
        body.addAll([
          GreetingHero(title: '${first.isEmpty ? 'You' : first} on site', subtitle: '${n(stats?.a)} assigned project${stats?.a == 1 ? '' : 's'} · ${n(stats?.b)} open task${stats?.b == 1 ? '' : 's'}', badge: badge),
          if (!verified && cl.done < cl.total) SetupBanner(done: cl.done, total: cl.total),
          StatRow([(n(stats?.a), 'Projects', Icons.folder_outlined), (n(stats?.b), 'Open tasks', Icons.task_alt), ('${stats?.c ?? '—'}%', 'Avg progress', Icons.trending_up)]),
          _projectCard(context, pr, emptyTitle: 'No project yet', emptyText: 'Ask your company for a join code. Once they approve the link, their projects appear here.'),
          const SectionLabel('Your projects'),
          QuickTiles([
            (Icons.task_alt, 'Tasks', '${n(stats?.b)} open', () => context.go(AppRoutes.projects)),
            (Icons.groups_outlined, 'Team', 'Build your crew', () => context.go(AppRoutes.projects)),
            (Icons.description_outlined, 'Reports', 'Daily and weekly', () => context.go(AppRoutes.projects)),
            (Icons.payments_outlined, 'Finance', 'Requests and records', () => context.go(AppRoutes.projects)),
          ]),
        ]);
      case AccountType.business:
        final inq = stats?.extra['inquiry'] as Map?;
        body.addAll([
          GreetingHero(title: me.displayName.isEmpty ? 'Your shop' : me.displayName, subtitle: 'Your catalog, equipment and customer inquiries.', badge: badge, chips: [if (p['accepting_orders'] == true) '● Accepting orders']),
          if (!verified && cl.done < cl.total) SetupBanner(done: cl.done, total: cl.total),
          StatRow([(n(stats?.a), 'Products', Icons.inventory_2_outlined), (n(stats?.b), 'Equipment', Icons.construction_outlined), (n(stats?.c), 'Inquiries', Icons.mail_outline)]),
          DashCard(
            title: inq == null ? 'No inquiries yet' : 'Inquiry from ${inq['inquirer_name'] ?? 'a customer'}',
            child: Text(inq == null ? 'When a customer or company asks about your listings, it shows up here.' : '${inq['message'] ?? ''}', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          const SectionLabel('Quick access'),
          QuickTiles([
            (Icons.add, 'Add product', 'Catalog', () => context.go(AppRoutes.listings)),
            (Icons.mail_outline, 'Inquiries', '${n(stats?.c)} total', () => context.go(AppRoutes.messages)),
            (Icons.construction_outlined, 'Equipment', '${n(stats?.b)} listed', () => context.go(AppRoutes.listings)),
            (Icons.account_balance_wallet_outlined, 'Wallet', 'Balance and payouts', () => context.push(AppRoutes.wallet)),
          ]),
        ]);
      case AccountType.employer:
        body.addAll([
          GreetingHero(title: first.isEmpty ? 'Welcome' : first, subtitle: 'Need something fixed or built?', badge: badge),
          if (!verified && cl.done < cl.total) SetupBanner(done: cl.done, total: cl.total),
          const BuildHomeCard(),
          StatRow([(n(stats?.a), 'Jobs posted', Icons.work_outline), (n(stats?.b), 'Open', Icons.mail_outline), (n(stats?.c), 'Hired', Icons.handshake_outlined)]),
          const SectionLabel('Find a trade'),
          QuickTiles([
            for (final t in ['Electrician', 'Plumber', 'Painter', 'General Handyman']) (Icons.work_outline, t, 'Browse pros', () => context.go(AppRoutes.discover)),
          ]),
        ]);
    }
    body.add(HomeInbox(type: type));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: () async {
            ref.invalidate(accountProfileProvider);
            ref.invalidate(homeStatsProvider(type));
            ref.invalidate(myBuildProvider);
            ref.invalidate(invitationsProvider);
            ref.invalidate(approvalsProvider);
            ref.invalidate(notificationsProvider);
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: body),
        ),
      ),
    );
  }

  Widget _projectCard(BuildContext context, Map? pr, {required String emptyTitle, required String emptyText, (String, VoidCallback)? cta}) {
    if (pr == null) {
      return DashCard(
        title: emptyTitle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emptyText, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          if (cta != null) ...[const SizedBox(height: 10), PillButton(label: cta.$1, expand: false, height: 38, onPressed: cta.$2)],
        ]),
      );
    }
    final pct = num.tryParse('${pr['progress_pct'] ?? 0}') ?? 0;
    return DashCard(
      title: '${pr['name'] ?? 'Project'}',
      right: '$pct%',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlowBar(pct / 100),
        const SizedBox(height: 10),
        Row(children: [Pill(_pretty(pr['status']), tone: PillTone.ok), const SizedBox(width: 8), Text('${pr['city_town'] ?? ''}', style: TextStyle(fontSize: 12.5, color: AppColors.muted))]),
      ]),
    );
  }
}

String _pretty(Object? v) => (v ?? '').toString().replaceAll('_', ' ').trim().replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());

