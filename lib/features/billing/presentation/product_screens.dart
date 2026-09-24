import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../domain/billing_rules.dart';
import '../domain/product_rules.dart';
import 'billing_providers.dart';
import 'paystack_checkout.dart';

String catalogPrice(Map<String, dynamic> row) {
  final amount = row['amount_minor'];
  if (amount is! int) return '';
  return '${formatMinorAmount(amount, symbol: '')} ${row['currency_code'] ?? ''}'.trim();
}

class BoostPanel extends ConsumerStatefulWidget {
  const BoostPanel({required this.targetType, required this.targetId, required this.title, super.key});

  final String targetType;
  final String targetId;
  final String title;

  @override
  ConsumerState<BoostPanel> createState() => _BoostPanelState();
}

class _BoostPanelState extends ConsumerState<BoostPanel> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(_boostCatalogProvider(widget.targetType));
    final current = ref.watch(_boostsProvider(widget.targetId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: AppTextStyles.label),
        current.when(
          loading: () => const Text('Loading boost'),
          error: (error, _) => Text(ErrorHandler.toAppException(error).message),
          data: (rows) {
            final active = rows.cast<Map<String, dynamic>>().where((row) {
              final end = DateTime.tryParse('${row['ends_at'] ?? ''}');
              return end != null && end.isAfter(DateTime.now().toUtc());
            }).toList();
            if (active.isEmpty) return const Text('No active boost.');
            final row = active.first;
            return Text('Active ${row['duration_key']} · from ${row['starts_at']} UTC · until ${row['ends_at']} UTC');
          },
        ),
        catalog.when(
          loading: () => const Text('Loading boost prices'),
          error: (error, _) => Text(ErrorHandler.toAppException(error).message),
          data: (rows) => Column(
            children: [
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${row['duration_key']} · ${row['duration_hours']} hours'),
                  subtitle: Text(catalogPrice(row)),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _buy(row),
                    child: const Text('Boost'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _buy(Map<String, dynamic> row) async {
    setState(() => _busy = true);
    try {
      await startPaystackCheckout(context, ref, {
        'p_purpose': 'boost',
        'p_target_type': widget.targetType,
        'p_target_id': widget.targetId,
        'p_duration_key': row['duration_key'],
      });
      ref.invalidate(_boostsProvider(widget.targetId));
    } catch (error) {
      if (mounted) showBillingError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final _boostCatalogProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, target) async {
  final rows = await ref.watch(billingRepositoryProvider).catalog('boost_catalog', '');
  return rows.where((row) => row['target_type'] == target).toList();
});

final _boostsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, targetId) {
  return ref.watch(billingRepositoryProvider).boostsFor(targetId);
});

class XidScreen extends ConsumerStatefulWidget {
  const XidScreen({super.key});

  @override
  ConsumerState<XidScreen> createState() => _XidScreenState();
}

class _XidScreenState extends ConsumerState<XidScreen> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    final catalog = ref.watch(_xidCatalogProvider);
    final mine = ref.watch(_xidProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('XID')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text('Basic XID is free. A paid service is activated only after BAID X confirms the payment.'),
          mine.when(
            loading: () => const AppLoader(message: 'Loading XID'),
            error: (error, _) => Text(ErrorHandler.toAppException(error).message),
            data: (rows) {
              if (rows.isEmpty) return const Text('Current service: Basic · Free');
              final row = rows.first;
              return Text('Current service: ${row['service']} · until ${row['ends_at']} UTC');
            },
          ),
          catalog.when(
            loading: () => const Text('Loading XID prices'),
            error: (error, _) => Text(ErrorHandler.toAppException(error).message),
            data: (rows) => Column(
              children: [
                for (final row in rows)
                  if (xidAllowed(type, '${row['service']}'))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${row['label']} · ${catalogPrice(row)} / year'),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _buy('${row['service']}'),
                        child: const Text('Choose'),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(String service) async {
    setState(() => _busy = true);
    try {
      await startPaystackCheckout(context, ref, {'p_purpose': 'xid', 'p_xid': service});
      ref.invalidate(_xidProvider);
    } catch (error) {
      if (mounted) showBillingError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final _xidCatalogProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(billingRepositoryProvider).catalog('xid_catalog', '');
});

final _xidProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authStateProvider).asData?.value == null) return const [];
  return ref.watch(billingRepositoryProvider).myXid();
});

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  final _selected = <String>{};
  String? _package;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
    if (type != 'business') {
      return const Scaffold(body: Center(child: Text('Marketplace promotions are for business accounts.')));
    }
    final catalog = ref.watch(_promoCatalogProvider);
    final listings = ref.watch(_promoListingsProvider);
    final active = ref.watch(_promoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace promotion')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          active.when(
            loading: () => const Text('Loading promotion'),
            error: (error, _) => Text(ErrorHandler.toAppException(error).message),
            data: (row) => Text(row == null ? 'No active promotion.' : '${row['package']} · ${row['listing_limit']} listings · until ${row['ends_at']} UTC'),
          ),
          catalog.when(
            loading: () => const AppLoader(message: 'Loading packages'),
            error: (error, _) => Text(ErrorHandler.toAppException(error).message),
            data: (rows) => Column(
              children: [
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: _package == row['package'],
                    title: Text('${row['label']} · ${catalogPrice(row)}'),
                    subtitle: Text('${row['listing_limit']} listings · ${row['duration_hours']} hours'),
                    onTap: () => setState(() => _package = '${row['package']}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Your listings', style: AppTextStyles.label),
          listings.when(
            loading: () => const Text('Loading listings'),
            error: (error, _) => Text(ErrorHandler.toAppException(error).message),
            data: (rows) => Column(
              children: [
                for (final row in rows)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row['title']}'),
                    value: _selected.contains('${row['id']}'),
                    onChanged: (value) => setState(() {
                      final id = '${row['id']}';
                      if (value == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Pay for promotion', isLoading: _busy, onPressed: _buy),
        ],
      ),
    );
  }

  Future<void> _buy() async {
    final catalog = ref.read(_promoCatalogProvider).asData?.value ?? const [];
    final chosen = catalog.cast<Map<String, dynamic>>().where((row) => row['package'] == _package).toList();
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a package.')));
      return;
    }
    final problem = listingSelectionError(selected: _selected.length, limit: chosen.first['listing_limit'] as int);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _busy = true);
    try {
      await startPaystackCheckout(context, ref, {
        'p_purpose': 'promotion',
        'p_package': _package,
        'p_listing_ids': _selected.toList(),
      });
      ref.invalidate(_promoProvider);
    } catch (error) {
      if (mounted) showBillingError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final _promoCatalogProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(billingRepositoryProvider).catalog('promotion_catalog', '');
});

final _promoListingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authStateProvider).asData?.value == null) return const [];
  return ref.watch(billingRepositoryProvider).myListings();
});

final _promoProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  if (ref.watch(authStateProvider).asData?.value == null) return null;
  return ref.watch(billingRepositoryProvider).activePromotion();
});

class CompanyBillingScreen extends ConsumerWidget {
  const CompanyBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(_companyBillingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Company billing')),
      body: billing.when(
        loading: () => const AppLoader(message: 'Loading company billing'),
        error: (error, _) => AppErrorView(
          message: ErrorHandler.toAppException(error).message,
          onRetry: () => ref.invalidate(_companyBillingProvider),
        ),
        data: (row) {
          final sub = row['subscription'] is Map ? Map<String, dynamic>.from(row['subscription'] as Map) : null;
          final entitlements = sub?['entitlements'] is Map ? Map<String, dynamic>.from(sub!['entitlements'] as Map) : const <String, dynamic>{};
          final payments = row['payments'] is List ? row['payments'] as List : const [];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('${row['company_name']}', style: AppTextStyles.title),
              Text(sub == null ? 'No company plan is active.' : '${sub['tier']} · ${sub['status']}'),
              if (sub != null) ...[
                Text('Current price ${sub['amount_minor']} ${sub['currency_code']} / ${sub['billing_interval']}'),
                Text('Monthly catalog price ${sub['monthly_amount']} · annual ${sub['annual_amount']}'),
                if (sub['is_founding'] == true) Text('Founding prices ${sub['founding_monthly_amount']} / ${sub['founding_annual_amount']}'),
                Text('Activated ${sub['activated_at'] ?? 'not set'} UTC'),
                Text('Period ${sub['current_period_start']} to ${sub['current_period_end']} UTC'),
                Text(sub['founding_price_lock_end'] == null ? 'No founding price lock.' : 'Founding price lock until ${sub['founding_price_lock_end']} UTC'),
              ],
              const SizedBox(height: AppSpacing.md),
              const Text('Capacity from the current plan', style: AppTextStyles.label),
              for (final line in capacityLines(entitlements)) Text(line),
              if (capacityLines(entitlements).isEmpty) const Text('This plan has no organization capacity figures.'),
              const SizedBox(height: AppSpacing.md),
              const Text('Company payments', style: AppTextStyles.label),
              for (final raw in payments)
                Text('${(raw as Map)['purpose']} · ${raw['status']} · ${raw['amount_minor']} ${raw['currency_code']} · ${raw['provider_reference']}'),
              const SizedBox(height: AppSpacing.md),
              const Text('Plan changes use Billing. Only a company owner can open this page.'),
            ],
          );
        },
      ),
    );
  }
}

final _companyBillingProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  if (ref.watch(authStateProvider).asData?.value == null) throw StateError('Not signed in');
  return ref.watch(billingRepositoryProvider).companyBilling();
});

class ReviewerScreen extends ConsumerWidget {
  const ReviewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(_reviewQueueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verification review')),
      body: queue.when(
        loading: () => const AppLoader(message: 'Loading requests'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(_reviewQueueProvider)),
        data: (rows) {
          if (rows.isEmpty) return const Center(child: Text('No pending verification requests.'));
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${row['display_name'] ?? 'Account'} · ${row['verification_kind']}'),
                  subtitle: Text('Requested ${row['created_at']} · payment ${row['payment_status'] ?? 'none'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () => _decide(context, ref, '${row['id']}', 'verified'), child: const Text('Approve')),
                      TextButton(onPressed: () => _decide(context, ref, '${row['id']}', 'rejected'), child: const Text('Reject')),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, String id, String decision) async {
    try {
      await ref.read(billingRepositoryProvider).decideVerification(id, decision);
      ref.invalidate(_reviewQueueProvider);
    } catch (error) {
      if (context.mounted) showBillingError(context, error);
    }
  }
}

final _reviewQueueProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authStateProvider).asData?.value == null) return const [];
  return ref.watch(billingRepositoryProvider).pendingReviews();
});
