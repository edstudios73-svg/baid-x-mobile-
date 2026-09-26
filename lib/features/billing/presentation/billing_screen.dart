import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
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
          final palette = context.palette;
          return PageBody(
            children: [
              Text('Current plan', style: AppTextStyles.caption.copyWith(color: palette.textMuted)),
              const SizedBox(height: AppSpacing.xxs),
              Text(_statusLine(snapshot), style: AppTextStyles.title.copyWith(color: palette.text)),
              if (snapshot.refundDeadline != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text('Refund window ends ${snapshot.refundDeadline!.toUtc()} UTC', style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted)),
              ],
              const SizedBox(height: AppSpacing.md),
              if (snapshot.foundingEligible) ...[
                const InfoNote('Founding price is available until the slot or the 90-day program ends.'),
                const SizedBox(height: AppSpacing.xs),
              ],
              const InfoNote('A paid plan does not verify this account.'),
              const SizedBox(height: AppSpacing.xs),
              const InfoNote('Protected payments are off.'),
              const SizedBox(height: AppSpacing.md),
              if (snapshot.subscription != null && snapshot.subscription!['status'] != 'cancel_at_period_end')
                AppButton(label: 'Cancel renewal', outlined: true, isLoading: _busy, onPressed: _cancel),
              if ((snapshot.subscription?['trial_end'] == null) && snapshot.subscription == null)
                AppButton(label: 'Start 30-day Pro trial', outlined: true, isLoading: _busy, onPressed: _trial),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Plans'),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Monthly')),
                  ButtonSegment(value: true, label: Text('Annual')),
                ],
                selected: {_annual},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _annual = value.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              plans.when(
                loading: () => const AppLoader(message: 'Loading plans'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => AppListGroup(
                  children: [
                    for (final plan in rows) _planTile(snapshot, plan),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Payments'),
              history.when(
                loading: () => const Text('Loading payments'),
                error: (error, _) => Text(ErrorHandler.toAppException(error).message),
                data: (rows) => rows.isEmpty
                    ? Text('No payments yet', style: AppTextStyles.bodyMuted.copyWith(color: palette.textMuted))
                    : AppListGroup(
                        children: [
                          for (final row in rows)
                            AppListRow(
                              leading: const AppAvatar.icon(Icons.receipt_long_outlined, size: 40),
                              title: statusLabel('${row['purpose']}'),
                              subtitle: [
                                '${row['created_at'] ?? ''}'.split('T').first,
                                if (row['invoice_reference'] != null) '${row['invoice_reference']}',
                              ].where((part) => part.isNotEmpty).join(' · '),
                              badge: StatusBadge.forStatus('${row['status']}'),
                              trailing: Text(
                                _paymentAmount(row),
                                style: AppTextStyles.label.copyWith(color: palette.text, fontFeatures: const [FontFeature.tabularFigures()]),
                              ),
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

  Widget _planTile(BillingSnapshot snapshot, PlanOffer plan) {
    final founding = snapshot.foundingEligible || snapshot.subscription?['is_founding'] == true;
    final amount = _annual
        ? (founding ? plan.foundingAnnualAmount ?? plan.annualAmount : plan.annualAmount)
        : (founding ? plan.foundingMonthlyAmount ?? plan.monthlyAmount : plan.monthlyAmount);
    if (amount == null) return const SizedBox.shrink();
    final price = formatMinorAmount(amount, symbol: plan.symbol);
    final interval = _annual ? 'year' : 'month';
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(statusLabel(plan.tier), style: AppTextStyles.label.copyWith(color: palette.text, fontSize: 15))),
              Text('$price / $interval', style: AppTextStyles.numeric.copyWith(color: palette.text, fontSize: 18)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            plan.tier == 'access' ? 'Included' : 'Renews at this price unless you cancel. Access stays until the period ends.',
            style: AppTextStyles.caption.copyWith(color: palette.textMuted),
          ),
          if (plan.tier != 'access') ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: 'Choose', outlined: true, onPressed: _busy ? null : () => _checkout(plan, interval)),
          ],
        ],
      ),
    );
  }

  String _paymentAmount(Map<String, dynamic> row) {
    final minor = row['amount_minor'];
    final currency = '${row['currency_code'] ?? ''}';
    if (minor is! int) return '$minor $currency'.trim();
    return formatMinorAmount(minor, symbol: currency.toUpperCase() == 'GHS' ? 'GH₵' : '$currency ');
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
