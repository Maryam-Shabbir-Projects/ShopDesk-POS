import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/sales/domain/pricing_service.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';

/// A sale being built, before it is saved. The Sell screen and the
/// manual Add sale screen both use this same model.
class SaleDraft {
  const SaleDraft({
    this.lines = const {},
    this.discountPct = 0,
    this.taxRate,
    this.customer = '',
    this.payment = PaymentMethod.cash,
    this.date,
  });

  /// productId -> quantity
  final Map<int, int> lines;
  final double discountPct;

  /// Null means "use the default tax rate from settings".
  final double? taxRate;
  final String customer;
  final PaymentMethod payment;
  final DateTime? date;

  int get itemCount => lines.values.fold(0, (a, b) => a + b);
  bool get isEmpty => lines.isEmpty;

  double subtotal(List<Product> products) {
    var sum = 0.0;
    lines.forEach((id, qty) {
      final match = products.where((p) => p.id == id).firstOrNull;
      if (match != null) sum += match.price * qty;
    });
    return sum;
  }

  SaleTotals totals(List<Product> products, double defaultTaxRate) => PricingService.calculate(
        subtotal: subtotal(products),
        discountPct: discountPct,
        taxRate: taxRate ?? defaultTaxRate,
      );

  SaleDraft copyWith({
    Map<int, int>? lines,
    double? discountPct,
    double? taxRate,
    String? customer,
    PaymentMethod? payment,
    DateTime? date,
  }) =>
      SaleDraft(
        lines: lines ?? this.lines,
        discountPct: discountPct ?? this.discountPct,
        taxRate: taxRate ?? this.taxRate,
        customer: customer ?? this.customer,
        payment: payment ?? this.payment,
        date: date ?? this.date,
      );
}

class SaleDraftNotifier extends Notifier<SaleDraft> {
  @override
  SaleDraft build() => const SaleDraft();

  /// Returns an error message when the product cannot be added.
  String? add(Product product) {
    final current = state.lines[product.id!] ?? 0;
    if (current >= product.stock) {
      return product.stock <= 0
          ? '${product.name} is out of stock'
          : 'Only ${product.stock} of ${product.name} in stock';
    }
    state = state.copyWith(lines: {...state.lines, product.id!: current + 1});
    return null;
  }

  void decrement(int productId) {
    final current = state.lines[productId] ?? 0;
    final next = {...state.lines};
    current <= 1 ? next.remove(productId) : next[productId] = current - 1;
    state = state.copyWith(lines: next);
  }

  void remove(int productId) => state = state.copyWith(lines: {...state.lines}..remove(productId));
  void setDiscount(double v) => state = state.copyWith(discountPct: v);
  void setTax(double v) => state = state.copyWith(taxRate: v);
  void setCustomer(String v) => state = state.copyWith(customer: v);
  void setPayment(PaymentMethod v) => state = state.copyWith(payment: v);
  void setDate(DateTime v) => state = state.copyWith(date: v);
  void clear() => state = const SaleDraft();
}

typedef SaleDraftProvider = NotifierProvider<SaleDraftNotifier, SaleDraft>;

/// Draft used by the Sell (point of sale) screen.
final SaleDraftProvider posDraftProvider = NotifierProvider<SaleDraftNotifier, SaleDraft>(SaleDraftNotifier.new);

/// Draft used by the manual Add sale screen.
final SaleDraftProvider manualDraftProvider = NotifierProvider<SaleDraftNotifier, SaleDraft>(SaleDraftNotifier.new);
