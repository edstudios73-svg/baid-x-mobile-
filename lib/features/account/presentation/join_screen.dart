import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../data/profile_data.dart';
import 'profile_pages.dart' show backHead;

/// Opens an organization invitation link (website js/orgs.js joinView):
/// accepts it, then shows the organization.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({required this.token, super.key});
  final String token;
  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _accept();
  }

  Future<void> _accept() async {
    final t = Uri.decodeComponent(widget.token).trim();
    try {
      final id = await rpcCall('accept_org_invitation', {'p_token': t});
      ref.invalidate(myOrgsProvider);
      if (mounted) context.replace('${AppRoutes.orgs}/$id');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              backHead(context, 'Join'),
              if (_failed)
                DashEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: 'Couldn\'t accept',
                  text: 'This invitation is invalid, expired, used, or sent to a different account.',
                  action: SmallButton('My organizations', onPressed: () => context.go(AppRoutes.orgs)),
                )
              else
                const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
            ]),
          ),
        ),
      );
}
