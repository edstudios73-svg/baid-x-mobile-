import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import 'marketplace_screen.dart' show listingKindIcon;
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
          final palette = context.palette;
          final sellerVerified = ref.watch(businessProfileProvider(record.businessId)).asData?.value?['verified'] == true;
          return PageBody(
            children: [
              Row(
                children: [
                  StatusBadge(label: listingKindLabel(record.kind)),
                  if (mine) ...[
                    const SizedBox(width: AppSpacing.xs),
                    StatusBadge(
                      label: record.isPublic ? 'Public' : 'Hidden',
                      tone: record.isPublic ? BadgeTone.success : BadgeTone.neutral,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(record.title, style: AppTextStyles.headline.copyWith(color: palette.text)),
              if (record.price != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(Formatters.price(record.price!, record.currency), style: AppTextStyles.numeric.copyWith(color: palette.text)),
              ],
              if (record.businessLocation.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: palette.textMuted),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(child: Text(record.businessLocation, style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted))),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'Details'),
              Text(record.summary.isEmpty ? 'No description yet.' : record.summary, style: AppTextStyles.body.copyWith(color: palette.text)),
              if (record.businessName.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Sold by'),
                AppListGroup(
                  children: [
                    AppListRow(
                      leading: AppAvatar(name: record.businessName),
                      title: record.businessName,
                      subtitle: record.businessSummary,
                      badge: sellerVerified ? const StatusBadge.verified() : null,
                      onTap: () => context.push('/businesses/${record.businessId}'),
                    ),
                  ],
                ),
              ],
              if (mine) ...[
                const SizedBox(height: AppSpacing.lg),
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
      bottomNavigationBar: BottomActionBar(
        child: AppButton(label: 'Create listing', onPressed: () => context.push(AppRoutes.createListing)),
      ),
      body: listings.when(
        loading: () => const AppLoader(message: 'Loading your listings'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(myListingsProvider)),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No listings found',
              message: 'Your products, materials, and equipment will appear here.',
            );
          }
          return PageBody(
            children: [
              AppListGroup(
                children: [
                  for (final listing in rows)
                    AppListRow(
                      leading: AppAvatar.icon(listingKindIcon(listing.kind), size: 48),
                      title: listing.title,
                      subtitle: [
                        listingKindLabel(listing.kind),
                        if (listing.price != null) Formatters.price(listing.price!, listing.currency),
                      ].join(' · '),
                      badge: StatusBadge(
                        label: listing.isPublic ? 'Public' : 'Hidden',
                        tone: listing.isPublic ? BadgeTone.success : BadgeTone.neutral,
                      ),
                      onTap: () => context.push('/listings/${listing.id}/edit'),
                    ),
                ],
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
      bottomNavigationBar: BottomActionBar(
        child: AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
      ),
      body: PageBody(
        children: [
          const SizedBox(height: AppSpacing.xs),
          const SectionHeader(title: 'What are you listing?'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final kind in listingKinds)
                ChoiceChip(
                  avatar: Icon(listingKindIcon(kind), size: 18),
                  label: Text(listingKindLabel(kind)),
                  selected: _kind == kind,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(label: 'Title', controller: _title, hint: 'e.g. Cement 42.5R, 50kg bag'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Description', controller: _summary, maxLines: 6, minLines: 3),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'Price',
                  controller: _price,
                  hint: 'Leave blank to ask buyers to contact you',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(flex: 2, child: AppTextField(label: 'Currency', controller: _currency)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show on the marketplace'),
            subtitle: const Text('Hidden listings are only visible to you.'),
            value: _public,
            onChanged: (value) => setState(() => _public = value),
          ),
          if (_error != null) ...[const SizedBox(height: AppSpacing.sm), FormMessage(_error!)],
          if (_notice != null) ...[const SizedBox(height: AppSpacing.sm), FormMessage(_notice!, success: true)],
          if (widget.listingId != null) ...[
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.palette.danger),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete listing'),
              onPressed: _confirmDelete,
            ),
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
          final palette = context.palette;
          final name = '${profile['business_name'] ?? 'Business'}';
          final meta = ['${profile['category'] ?? ''}', '${profile['location_label'] ?? ''}'].where((v) => v.isNotEmpty).join(' · ');
          final summary = '${profile['summary'] ?? ''}';
          return PageBody(
            children: [
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  AppAvatar(name: name, size: 64),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.title.copyWith(color: palette.text)),
                        if (meta.isNotEmpty) Text(meta, style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted)),
                        if (data['verified'] == true) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          const StatusBadge.verified(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'About'),
                Text(summary, style: AppTextStyles.body.copyWith(color: palette.text)),
              ],
              const SizedBox(height: AppSpacing.lg),
              reviews.when(
                loading: () => const Text('Loading reviews'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: rows.isEmpty ? 'No reviews yet' : '${rows.length} reviews'),
                    if (rows.isNotEmpty)
                      AppListGroup(
                        children: [
                          for (final review in rows)
                            AppListRow(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 18, color: AppColors.yellowPressed),
                                  const SizedBox(width: 2),
                                  Text('${review.rating}', style: AppTextStyles.label.copyWith(color: palette.text)),
                                ],
                              ),
                              title: review.body.isEmpty ? 'No comment' : review.body,
                            ),
                        ],
                      ),
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
