import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/page_body.dart';
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
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: AppTextStyles.label,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('List a product'),
              onPressed: () => requireAuthentication(context, ref, () => context.push(AppRoutes.createListing)),
            ),
          ),
        ],
      ),
      body: PageBody(
        children: [
          AppSearchField(
            controller: _search,
            hint: 'Search materials, equipment, services',
            onChanged: (_) => _reset(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _KindChip(label: 'All', selected: _kind == null, onTap: () => _reset(() => _kind = null)),
                for (final kind in listingKinds)
                  _KindChip(
                    label: listingKindLabel(kind),
                    selected: _kind == kind,
                    onTap: () => _reset(() => _kind = _kind == kind ? null : kind),
                  ),
                const SizedBox(width: AppSpacing.xs),
                ActionChip(label: const Text('Jobs'), onPressed: () => context.go(AppRoutes.work)),
                const SizedBox(width: AppSpacing.xs),
                ActionChip(label: const Text('Workers'), onPressed: () => context.go(AppRoutes.workers)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppSearchField(
                  controller: _location,
                  hint: 'Location',
                  icon: Icons.place_outlined,
                  onChanged: (_) => _reset(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 2,
                child: AppSearchField(
                  controller: _maxPrice,
                  hint: 'Max price',
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _reset(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          page.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppLoader(message: 'Loading listings'),
            ),
            error: (error, _) => AppErrorView(
              message: ErrorHandler.toAppException(error).message,
              onRetry: () => ref.invalidate(publicListingsProvider(_query)),
            ),
            data: (rows) {
              final shown = [..._loaded, ...rows];
              if (shown.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No listings found',
                  message: 'Public products, equipment, and rentals will appear here.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppListGroup(children: [for (final listing in shown) ListingRow(listing: listing)]),
                  if (rows.length == listingPageSize) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Load more',
                      outlined: true,
                      onPressed: () => setState(() {
                        _loaded.addAll(rows);
                        _offset += listingPageSize;
                      }),
                    ),
                  ],
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

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// One marketplace listing: icon for its type, title, type · place · seller, price.
class ListingRow extends StatelessWidget {
  const ListingRow({required this.listing, super.key});

  final ListingRecord listing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppListRow(
      leading: AppAvatar.icon(listingKindIcon(listing.kind), size: 48),
      title: listing.title,
      subtitle: [
        listingKindLabel(listing.kind),
        listing.businessLocation,
        listing.businessName,
      ].where((part) => part.isNotEmpty).join(' · '),
      trailing: listing.price == null
          ? null
          : Text(
              Formatters.price(listing.price!, listing.currency),
              style: AppTextStyles.label.copyWith(color: palette.text, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
      onTap: () => context.push('/listings/${listing.id}'),
    );
  }
}

IconData listingKindIcon(String kind) {
  return switch (kind) {
    'product' => Icons.inventory_2_outlined,
    'equipment' => Icons.construction_outlined,
    'rental' => Icons.event_repeat_outlined,
    'service' => Icons.handyman_outlined,
    _ => Icons.sell_outlined,
  };
}
