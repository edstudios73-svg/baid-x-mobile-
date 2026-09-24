import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
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
            return const Center(child: Text('No verification products are offered for this account.'));
          }
          final mine = records.asData?.value ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Text('Payment asks BAID X to review the check. It does not mark the account verified.'),
              const SizedBox(height: AppSpacing.md),
              for (final product in rows) _product(product, mine),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${product['label']} · ${catalogPrice(product)}'),
      subtitle: Text('${verificationStateLabel(status)}. A paid plan does not verify this account.'),
      trailing: open
          ? TextButton(
              onPressed: _busy ? null : () => _buy('${product['product_code']}'),
              child: const Text('Purchase'),
            )
          : null,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(label: 'Rating from 1 to 5', controller: _rating, keyboardType: TextInputType.number),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(label: 'Review', controller: _body),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Send review', isLoading: _saving, onPressed: _send),
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
