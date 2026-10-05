import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../account/data/profile_data.dart';
import '../../account/presentation/extra_screens.dart';
import '../../account_type/domain/account_type.dart';
import '../../tabs/data/tabs_data.dart';
import '../data/workspace_data.dart';
import 'ws_common.dart';

/// The inbox under every member Home (website js/dash.js inbox): project
/// invitations for workers and PMs, approvals for companies, then the five
/// newest unread updates.
class HomeInbox extends ConsumerWidget {
  const HomeInbox({required this.type, super.key});
  final AccountType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final out = <Widget>[];
    if (type == AccountType.worker || type == AccountType.projectManager) {
      final n = (ref.watch(invitationsProvider).asData?.value ?? const []).length;
      if (n > 0) {
        out.add(WsInboxCard(icon: Icons.mail_outline_rounded, title: '$n project invitation${n > 1 ? 's' : ''}', sub: 'Review and reply', count: n, onTap: () => context.push(AppRoutes.invites)));
      }
    }
    if (type == AccountType.company) {
      final a = ref.watch(approvalsProvider).asData?.value;
      final n = a == null ? 0 : approvalsCount(a);
      if (n > 0) {
        out.add(WsInboxCard(warn: true, icon: Icons.task_alt_rounded, title: '$n item${n > 1 ? 's' : ''} need your approval', sub: 'Workers, requests, payments, reports and completions', count: n, onTap: () => context.push(AppRoutes.approvals)));
      }
    }
    final notes = (ref.watch(notificationsProvider).asData?.value ?? const <Json>[]).where((n) => n['read_at'] == null).take(5).toList();
    if (notes.isNotEmpty) {
      out.add(const SectionLabel('Updates'));
      for (final n in notes) {
        out.add(DashRow(
          icon: Icons.notifications_none_rounded,
          title: '${n['title'] ?? 'BAID X'}',
          sub: '${n['body'] ?? ''}',
          trailing: Text(ago(n['created_at']), style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C8C8C))),
          onTap: () {
            sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', '${n['id']}').then((_) => ref.invalidate(notificationsProvider));
            final to = appPathFor(n['href'], projectId: asMap(n['meta'])['project_id']);
            if (to != null) context.push(to);
          },
        ));
      }
    }
    if (out.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out));
  }
}
