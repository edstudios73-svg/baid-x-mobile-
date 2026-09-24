import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../domain/billing_rules.dart';
import 'billing_providers.dart';

Future<void> startPaystackCheckout(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> args, {
  String symbol = '',
}) async {
  final payment = await ref.read(billingRepositoryProvider).startCheckout(args);
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
  if (!context.mounted) return;
  final amount = payment['amount_minor'] is int
      ? formatMinorAmount(payment['amount_minor'] as int, symbol: symbol)
      : '${payment['amount_minor']}';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Payment $amount is pending. Returning from Paystack does not activate it. Reference ${payment['reference']}.')),
  );
}

void showBillingError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.toAppException(error).message)));
}
