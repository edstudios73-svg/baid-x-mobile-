import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/page_body.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: PageBody(
        children: [
          Text(
            'Browse live listings on BAID X.',
            style: AppTextStyles.bodyMuted.copyWith(color: context.palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          const DirectoryLinks(),
        ],
      ),
    );
  }
}

/// Entry points to the directories that load real BAID X data.
class DirectoryLinks extends StatelessWidget {
  const DirectoryLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return AppListGroup(
      children: [
        AppListRow(
          leading: const AppAvatar.icon(Icons.work_outline),
          title: 'Jobs',
          subtitle: 'Open work posted by employers and companies.',
          subtitleLines: 2,
          onTap: () => context.go(AppRoutes.work),
        ),
        AppListRow(
          leading: const AppAvatar.icon(Icons.person_search_outlined),
          title: 'Skilled workers',
          subtitle: 'Masons, electricians, plumbers, drivers and more.',
          subtitleLines: 2,
          onTap: () => context.go(AppRoutes.workers),
        ),
        AppListRow(
          leading: const AppAvatar.icon(Icons.storefront_outlined),
          title: 'Marketplace',
          subtitle: 'Materials, equipment, rentals and services from businesses.',
          subtitleLines: 2,
          onTap: () => context.go(AppRoutes.marketplace),
        ),
      ],
    );
  }
}
