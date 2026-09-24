String formatMinorAmount(int amountMinor, {required String symbol, int decimalPlaces = 2}) {
  final scale = decimalPlaces <= 0 ? 1 : List.filled(decimalPlaces, 10).fold<int>(1, (value, item) => value * item);
  final whole = amountMinor ~/ scale;
  final fraction = (amountMinor.abs() % scale).toString().padLeft(decimalPlaces, '0');
  if (decimalPlaces <= 0) return '$symbol$whole';
  return '$symbol$whole.$fraction';
}

class PlanOffer {
  const PlanOffer({
    required this.id,
    required this.tier,
    required this.monthlyAmount,
    required this.annualAmount,
    required this.foundingMonthlyAmount,
    required this.foundingAnnualAmount,
    required this.currencyCode,
    required this.symbol,
    required this.entitlements,
  });

  final String id;
  final String tier;
  final int? monthlyAmount;
  final int? annualAmount;
  final int? foundingMonthlyAmount;
  final int? foundingAnnualAmount;
  final String currencyCode;
  final String symbol;
  final Map<String, dynamic> entitlements;
}

class BillingSnapshot {
  const BillingSnapshot({
    required this.accountType,
    required this.subscription,
    required this.entitlements,
    required this.foundingEligible,
    required this.protectedPaymentsEnabled,
    this.refundDeadline,
  });

  final String accountType;
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic> entitlements;
  final bool foundingEligible;
  final bool protectedPaymentsEnabled;
  final DateTime? refundDeadline;
}
