import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../billing/domain/product_rules.dart';
import '../../billing/presentation/billing_providers.dart';
import '../../billing/presentation/paystack_checkout.dart';
import '../../billing/presentation/product_screens.dart';
import '../domain/trust_rules.dart';
import 'trust_providers.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(verificationProductsProvider);
    final records = ref.watch(myVerificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: products.when(
        loading: () => const AppLoader(message: 'Loading verification'),
        error: (error, _) => AppErrorView(
          message: ErrorHandler.toAppException(error).message,
          onRetry: () => ref.invalidate(verificationProductsProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No checks offered',
              message: 'No verification products are offered for this account.',
            );
          }
          final mine = records.asData?.value ?? const <Map<String, dynamic>>[];
          return PageBody(
            children: [
              const InfoNote('Payment asks BAID X to review the check. It does not mark the account verified.'),
              const SizedBox(height: AppSpacing.md),
              AppListGroup(children: [for (final product in rows) _product(product, mine)]),
            ],
          );
        },
      ),
    );
  }

  Widget _product(Map<String, dynamic> product, List<Map<String, dynamic>> mine) {
    final kind = '${product['verification_kind']}';
    final match = mine.where((row) => row['verification_kind'] == kind);
    final status = match.isEmpty ? null : '${match.first['status']}';
    final open = canPurchaseVerification(status);
    final palette = context.palette;
    final tone = switch (status) {
      'verified' => BadgeTone.success,
      'pending' => BadgeTone.warning,
      'rejected' => BadgeTone.danger,
      _ => BadgeTone.neutral,
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${product['label']}', style: AppTextStyles.label.copyWith(color: palette.text, fontSize: 15))),
              StatusBadge(label: verificationStateLabel(status), tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(catalogPrice(product), style: AppTextStyles.numeric.copyWith(color: palette.text, fontSize: 18)),
          const SizedBox(height: AppSpacing.xxs),
          Text('A paid plan does not verify this account.', style: AppTextStyles.caption.copyWith(color: palette.textMuted)),
          if (open) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: 'Purchase', isLoading: _busy, onPressed: () => _buy('${product['product_code']}')),
          ],
        ],
      ),
    );
  }

  Future<void> _buy(String productCode) async {
    setState(() => _busy = true);
    try {
      await startPaystackCheckout(context, ref, {
        'p_purpose': 'verification',
        'p_product_code': productCode,
      });
      ref.invalidate(myVerificationsProvider);
    } catch (error) {
      if (mounted) showBillingError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class ReviewForm extends ConsumerStatefulWidget {
  const ReviewForm({required this.subjectId, this.projectId, super.key});

  final String subjectId;
  final String? projectId;

  @override
  ConsumerState<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<ReviewForm> {
  final _body = TextEditingController();
  final _rating = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _body.dispose();
    _rating.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = int.tryParse(_rating.text.trim()) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Rate this work', style: AppTextStyles.label.copyWith(color: context.palette.text)),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: '$star of 5',
                onPressed: () => setState(() => _rating.text = '$star'),
                icon: Icon(
                  star <= selected ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 30,
                  color: star <= selected ? AppColors.yellowPressed : context.palette.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AppTextField(label: 'Review', controller: _body, maxLines: 4),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Send review', outlined: true, isLoading: _saving, onPressed: _send),
      ],
    );
  }

  Future<void> _send() async {
    final problem = validateReview(body: _body.text, rating: _rating.text);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null || user.id == widget.subjectId) return;
    setState(() => _saving = true);
    try {
      await ref.read(trustRepositoryProvider).addReview(
        userId: user.id,
        subjectId: widget.subjectId,
        rating: int.parse(_rating.text.trim()),
        body: _body.text,
        projectId: widget.projectId,
      );
      _body.clear();
      _rating.clear();
      ref.invalidate(subjectReviewsProvider(widget.subjectId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review sent.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.toAppException(error).message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
