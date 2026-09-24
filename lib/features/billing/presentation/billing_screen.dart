import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../domain/billing_rules.dart';
import 'billing_providers.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  var _annual = false;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingSnapshotProvider);
    final plans = ref.watch(rolePlansProvider);
    final history = ref.watch(paymentHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: billing.when(
        loading: () => const AppLoader(message: 'Loading billing'),
        error: (error, _) => AppErrorView(message: ErrorHandler.toAppException(error).message, onRetry: () => ref.invalidate(billingSnapshotProvider)),
        data: (snapshot) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(_statusLine(snapshot), style: AppTextStyles.body),
              if (snapshot.refundDeadline != null)
                Text('Refund window ends ${snapshot.refundDeadline!.toUtc()} UTC', style: AppTextStyles.bodyMuted),
              if (snapshot.foundingEligible) const Text('Founding price is available until the slot or the 90-day program ends.'),
              const Text('A paid plan does not verify this account.'),
              const Text('Protected payments are off.'),
              const SizedBox(height: AppSpacing.md),
              if (snapshot.subscription != null && snapshot.subscription!['status'] != 'cancel_at_period_end')
                AppButton(label: 'Cancel renewal', outlined: true, isLoading: _busy, onPressed: _cancel),
              if ((snapshot.subscription?['trial_end'] == null) && snapshot.subscription == null)
                AppButton(label: 'Start 30-day Pro trial', outlined: true, isLoading: _busy, onPressed: _trial),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Monthly')),
                  ButtonSegment(value: true, label: Text('Annual')),
                ],
                selected: {_annual},
                onSelectionChanged: (value) => setState(() => _annual = value.first),
              ),
              plans.when(
                loading: () => const AppLoader(message: 'Loading plans'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final plan in rows) _planTile(snapshot, plan),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Payments', style: AppTextStyles.label),
              history.when(
                loading: () => const Text('Loading payments'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => rows.isEmpty
                    ? const Text('No payments yet')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in rows)
                            Text('${row['purpose']} · ${row['status']} · ${row['amount_minor']} ${row['currency_code']} · ${row['created_at']} · ${row['invoice_reference'] ?? ''}'),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _planTile(BillingSnapshot snapshot, PlanOffer plan) {
    final founding = snapshot.foundingEligible || snapshot.subscription?['is_founding'] == true;
    final amount = _annual
        ? (founding ? plan.foundingAnnualAmount ?? plan.annualAmount : plan.annualAmount)
        : (founding ? plan.foundingMonthlyAmount ?? plan.monthlyAmount : plan.monthlyAmount);
    if (amount == null) return const SizedBox.shrink();
    final price = formatMinorAmount(amount, symbol: plan.symbol);
    final interval = _annual ? 'year' : 'month';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${plan.tier} · $price / $interval'),
      subtitle: Text(plan.tier == 'access' ? 'Included' : 'Renews at this price unless you cancel. Access stays until the period ends.'),
      trailing: plan.tier == 'access'
          ? null
          : TextButton(
              onPressed: _busy ? null : () => _checkout(plan, interval),
              child: const Text('Choose'),
            ),
    );
  }

  String _statusLine(BillingSnapshot snapshot) {
    final sub = snapshot.subscription;
    if (sub == null) return 'Access. No paid plan is active.';
    final until = sub['current_period_end'];
    return '${sub['tier']} · ${sub['status']}${until == null ? '' : ' · until $until'}';
  }

  Future<void> _checkout(PlanOffer plan, String interval) async {
    setState(() => _busy = true);
    try {
      final payment = await ref.read(billingRepositoryProvider).startCheckout({
        'p_purpose': 'subscription',
        'p_plan_id': plan.id,
        'p_interval': interval,
      });
      if (!AppConfig.paystackPublicKey.startsWith('pk_test_')) {
        throw const AuthFlowException('Only Paystack test checkout is enabled.');
      }
      final started = await ref.read(billingRepositoryProvider).beginPaystack('${payment['reference']}');
      ref.invalidate(billingSnapshotProvider);
      ref.invalidate(paymentHistoryProvider);
      final url = Uri.tryParse('${started['authorization_url'] ?? ''}');
      if (url != null && await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      final amount = formatMinorAmount(payment['amount_minor'] as int, symbol: plan.symbol);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment $amount is pending. Returning from Paystack does not activate the plan. Reference ${payment['reference']}.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.toAppException(error).message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _trial() async {
    setState(() => _busy = true);
    try {
      await ref.read(billingRepositoryProvider).startTrial();
      ref.invalidate(billingSnapshotProvider);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.toAppException(error).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(billingRepositoryProvider).requestCancellation();
      ref.invalidate(billingSnapshotProvider);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.toAppException(error).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
