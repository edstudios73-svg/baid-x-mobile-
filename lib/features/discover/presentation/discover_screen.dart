import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_empty_state.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: [
          AppEmptyState(
            title: 'Discover is ready',
            message:
                'People, organizations, work, and marketplace results will load from the live BAID X project. Nothing is invented here.',
          ),
        ],
      ),
    );
  }
}
