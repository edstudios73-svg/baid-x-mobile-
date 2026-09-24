import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/listing_rules.dart';
import 'marketplace_providers.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  final _location = TextEditingController();
  final _maxPrice = TextEditingController();
  String? _kind;
  var _offset = 0;
  final _loaded = <ListingRecord>[];

  ListingQuery get _query => (
    search: _search.text,
    kind: _kind,
    location: _location.text,
    maxPrice: double.tryParse(_maxPrice.text.trim()),
    offset: _offset,
  );

  @override
  void dispose() {
    _search.dispose();
    _location.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(publicListingsProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text('Marketplace', style: AppTextStyles.display),
          const SizedBox(height: AppSpacing.xs),
          const Text('Materials, equipment, businesses, jobs, workers, and projects.', style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'List a product',
            onPressed: () => requireAuthentication(context, ref, () => context.push(AppRoutes.createListing)),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final kind in listingKinds)
                ChoiceChip(
                  label: Text(listingKindLabel(kind)),
                  selected: _kind == kind,
                  onSelected: (selected) => _reset(() => _kind = selected ? kind : null),
                ),
              ActionChip(label: const Text('Jobs'), onPressed: () => context.go(AppRoutes.work)),
              ActionChip(label: const Text('Workers'), onPressed: () => context.go(AppRoutes.workers)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Search listings', controller: _search, onChanged: (_) => _reset(() {})),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Business location', controller: _location, onChanged: (_) => _reset(() {})),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Highest price', controller: _maxPrice, keyboardType: TextInputType.number, onChanged: (_) => _reset(() {})),
          const SizedBox(height: AppSpacing.md),
          page.when(
            loading: () => const AppLoader(message: 'Loading listings'),
            error: (error, _) => AppErrorView(
              message: ErrorHandler.toAppException(error).message,
              onRetry: () => ref.invalidate(publicListingsProvider(_query)),
            ),
            data: (rows) {
              final shown = [..._loaded, ...rows];
              if (shown.isEmpty) {
                return const AppEmptyState(
                  title: 'No listings found',
                  message: 'Public products, equipment, and rentals will appear here.',
                );
              }
              return Column(
                children: [
                  for (final listing in shown)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(listing.title),
                      subtitle: Text([
                        listingKindLabel(listing.kind),
                        listing.businessLocation,
                        if (listing.price != null) '${listing.currency} ${listing.price}',
                      ].where((part) => part.isNotEmpty).join(' · ')),
                      onTap: () => context.push('/listings/${listing.id}'),
                    ),
                  if (rows.length == listingPageSize)
                    TextButton(
                      onPressed: () => setState(() {
                        _loaded.addAll(rows);
                        _offset += listingPageSize;
                      }),
                      child: const Text('Load more'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _reset(VoidCallback change) => setState(() {
    change();
    _loaded.clear();
    _offset = 0;
  });
}
