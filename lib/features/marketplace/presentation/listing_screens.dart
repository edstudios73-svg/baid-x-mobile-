import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../billing/presentation/product_screens.dart';
import '../../trust/presentation/trust_providers.dart';
import '../domain/listing_rules.dart';
import 'marketplace_providers.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(listingDetailProvider(id));
    final userId = ref.watch(authStateProvider).asData?.value?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: listing.when(
        loading: () => const AppLoader(message: 'Loading listing'),
        error: (error, _) => AppErrorView(
          message: ErrorHandler.toAppException(error).message,
          onRetry: () => ref.invalidate(listingDetailProvider(id)),
        ),
        data: (record) {
          if (record == null) {
            return const AppEmptyState(title: 'Listing not available', message: 'This listing is not public.');
          }
          final mine = userId != null && userId == record.businessId;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(record.title, style: AppTextStyles.title),
              Text('${listingKindLabel(record.kind)} · ${record.isPublic ? 'Public' : 'Hidden'}', style: AppTextStyles.bodyMuted),
              if (record.price != null) Text('${record.currency} ${record.price}', style: AppTextStyles.body),
              if (record.businessLocation.isNotEmpty) Text(record.businessLocation, style: AppTextStyles.bodyMuted),
              const SizedBox(height: AppSpacing.md),
              Text(record.summary.isEmpty ? 'No description yet.' : record.summary),
              const SizedBox(height: AppSpacing.md),
              if (record.businessName.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(record.businessName),
                  subtitle: Text([
                    if (ref.watch(businessProfileProvider(record.businessId)).asData?.value?['verified'] == true) 'Verified',
                    record.businessSummary,
                  ].where((part) => part.isNotEmpty).join(' · ')),
                  onTap: () => context.push('/businesses/${record.businessId}'),
                ),
              if (mine) ...[
                AppButton(label: 'Edit listing', outlined: true, onPressed: () => context.push('/listings/${record.id}/edit')),
                const SizedBox(height: AppSpacing.lg),
                BoostPanel(targetType: 'business_listing', targetId: id, title: 'Boost listing'),
              ],
            ],
          );
        },
      ),
    );
  }
}

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountType = ref.watch(accountProfileProvider).asData?.value?.accountType;
    if (!canManageListings(accountType)) {
      return const Scaffold(body: Center(child: Text('Only business accounts can manage listings.')));
    }
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      body: listings.when(
        loading: () => const AppLoader(message: 'Loading your listings'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(myListingsProvider)),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const AppEmptyState(title: 'No listings found', message: 'Your products, materials, and equipment will appear here.'),
                AppButton(label: 'Create listing', onPressed: () => context.push(AppRoutes.createListing)),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppButton(label: 'Create listing', onPressed: () => context.push(AppRoutes.createListing)),
              for (final listing in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(listing.title),
                  subtitle: Text('${listingKindLabel(listing.kind)} · ${listing.isPublic ? 'Public' : 'Hidden'}'),
                  onTap: () => context.push('/listings/${listing.id}/edit'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({this.listingId, super.key});

  final String? listingId;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _price = TextEditingController();
  final _currency = TextEditingController(text: 'GHS');
  var _kind = 'product';
  var _public = false;
  var _saving = false;
  var _loaded = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _price.dispose();
    _currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountType = ref.watch(accountProfileProvider).asData?.value?.accountType;
    if (!canManageListings(accountType)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: const Center(child: Text('Only business accounts can create listings.')),
      );
    }
    final existing = widget.listingId == null ? null : ref.watch(listingDetailProvider(widget.listingId!));
    if (existing != null) {
      existing.whenData((record) {
        if (record != null && !_loaded) {
          _loaded = true;
          _title.text = record.title;
          _summary.text = record.summary;
          _price.text = record.price?.toString() ?? '';
          _currency.text = record.currency;
          _kind = listingKinds.contains(record.kind) ? record.kind : 'product';
          _public = record.isPublic;
        }
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.listingId == null ? 'Create listing' : 'Edit listing')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(label: 'Title', controller: _title),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final kind in listingKinds) DropdownMenuItem(value: kind, child: Text(listingKindLabel(kind)))],
            onChanged: (value) => setState(() => _kind = value ?? 'product'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Description', controller: _summary),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Price', controller: _price, keyboardType: TextInputType.number),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Currency', controller: _currency),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show on the marketplace'),
            value: _public,
            onChanged: (value) => setState(() => _public = value),
          ),
          if (_error != null) Text(_error!, style: AppTextStyles.bodyMuted),
          if (_notice != null) Text(_notice!, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
          if (widget.listingId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: 'Delete listing', outlined: true, onPressed: _confirmDelete),
          ],
        ],
      ),
    );
  }

  double? get _parsedPrice {
    final text = _price.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    final problem = validateListing(title: _title.text, summary: _summary.text, kind: _kind, price: _price.text, currency: _currency.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      if (widget.listingId == null) {
        await repo.createListing(newListingRow(
          userId: user.id,
          title: _title.text,
          summary: _summary.text,
          kind: _kind,
          price: _parsedPrice,
          currency: _currency.text,
          isPublic: _public,
        ));
      } else {
        await repo.updateListing(widget.listingId!, listingUpdateRow(
          title: _title.text,
          summary: _summary.text,
          kind: _kind,
          price: _parsedPrice,
          currency: _currency.text,
          isPublic: _public,
        ));
      }
      ref.invalidate(myListingsProvider);
      if (mounted) {
        setState(() => _notice = 'Listing saved.');
        context.go(AppRoutes.listings);
      }
    } catch (error) {
      setState(() => _error = ErrorHandler.toAppException(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: const Text('This removes the listing from BAID X.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(marketplaceRepositoryProvider).deleteListing(widget.listingId!);
      ref.invalidate(myListingsProvider);
      if (mounted) context.go(AppRoutes.listings);
    } catch (error) {
      setState(() => _error = ErrorHandler.toAppException(error).message);
    }
  }
}

class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProfileProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: business.when(
        loading: () => const AppLoader(message: 'Loading business'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(businessProfileProvider(id))),
        data: (data) {
          if (data == null) {
            return const AppEmptyState(title: 'Business not available', message: 'This business is not listed.');
          }
          final profile = data['profile'] as Map<String, dynamic>;
          final reviews = ref.watch(subjectReviewsProvider(id));
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('${profile['business_name'] ?? 'Business'}', style: AppTextStyles.title),
              Text('${profile['category'] ?? ''} · ${profile['location_label'] ?? ''}', style: AppTextStyles.bodyMuted),
              if (data['verified'] == true) const Text('Verified', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.md),
              Text('${profile['summary'] ?? ''}'),
              const SizedBox(height: AppSpacing.md),
              reviews.when(
                loading: () => const Text('Loading reviews'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rows.isEmpty ? 'No reviews yet' : '${rows.length} reviews', style: AppTextStyles.bodyMuted),
                    for (final review in rows) Text('${review.rating} · ${review.body}', style: AppTextStyles.body),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
