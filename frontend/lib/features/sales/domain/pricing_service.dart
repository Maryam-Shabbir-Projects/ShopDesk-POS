import 'package:shopdesk/core/utils/formatters.dart';

class SaleTotals {
  const SaleTotals({
    required this.subtotal,
    required this.discount,
    required this.taxRate,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double taxRate;
  final double tax;
  final double total;
}

/// Pure maths so it can be unit tested and reused by every sale screen.
/// Discount is taken off first, then tax is charged on what is left.
abstract final class PricingService {
  static SaleTotals calculate({
    required double subtotal,
    required double discountPct,
    required double taxRate,
  }) {
    final d = discountPct.clamp(0, 100).toDouble();
    final t = taxRate.clamp(0, 100).toDouble();
    final discount = round2(subtotal * d / 100);
    final afterDiscount = subtotal - discount;
    final tax = round2(afterDiscount * t / 100);
    return SaleTotals(
      subtotal: round2(subtotal),
      discount: discount,
      taxRate: t,
      tax: tax,
      total: round2(afterDiscount + tax),
    );
  }
}
