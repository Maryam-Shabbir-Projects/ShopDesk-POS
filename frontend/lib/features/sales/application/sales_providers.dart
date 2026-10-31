import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/providers.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/sales/application/sale_draft.dart';
import 'package:shopdesk/features/sales/data/sqlite_sale_repository.dart';
import 'package:shopdesk/features/sales/domain/date_range.dart';
import 'package:shopdesk/features/sales/domain/pricing_service.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';
import 'package:shopdesk/features/sales/domain/sale_repository.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SqliteSaleRepository(ref.watch(databaseProvider)),
);

final salesInRangeProvider = FutureProvider.autoDispose.family<List<Sale>, DateRange>(
  (ref, range) => ref.watch(saleRepositoryProvider).between(range.from, range.to),
);

/// Turns a draft into a saved sale, then refreshes stock and sales lists.
class CheckoutService {
  CheckoutService(this._ref);
  final Ref _ref;

  Future<Sale> complete(SaleDraft draft) async {
    if (draft.isEmpty) throw StateError('Add at least one item.');
    final products = await _ref.read(productsProvider.future);
    final settings = _ref.read(settingsProvider);

    final items = <SaleItem>[];
    for (final entry in draft.lines.entries) {
      final p = products.firstWhere((x) => x.id == entry.key);
      if (entry.value > p.stock) throw StateError('Only ${p.stock} of ${p.name} in stock.');
      items.add(SaleItem(
        productId: p.id!,
        name: p.name,
        emoji: p.emoji,
        qty: entry.value,
        unitPrice: p.price,
      ));
    }
    final totals = PricingService.calculate(
      subtotal: items.fold(0.0, (a, i) => a + i.lineTotal),
      discountPct: draft.discountPct,
      taxRate: draft.taxRate ?? settings.taxRate,
    );
    final saved = await _ref.read(saleRepositoryProvider).create(Sale(
          createdAt: draft.date ?? DateTime.now(),
          customer: draft.customer.trim(),
          payment: draft.payment,
          subtotal: totals.subtotal,
          discount: totals.discount,
          taxRate: totals.taxRate,
          tax: totals.tax,
          total: totals.total,
          items: items,
        ));
    _ref.invalidate(productsProvider);
    _ref.invalidate(salesInRangeProvider);
    return saved;
  }
}

final checkoutServiceProvider = Provider<CheckoutService>((ref) => CheckoutService(ref));

/// Day and period shown on the Sales history screen.
class HistoryFilter {
  const HistoryFilter({required this.day, this.days = 1});
  final DateTime day;
  final int days;

  DateRange get range => DateRange(
        DateTime(day.year, day.month, day.day - (days - 1)),
        DateTime(day.year, day.month, day.day + 1),
      );

  HistoryFilter copyWith({DateTime? day, int? days}) =>
      HistoryFilter(day: day == null ? this.day : dayStart(day), days: days ?? this.days);
}

final historyFilterProvider = StateProvider<HistoryFilter>((ref) => HistoryFilter(day: dayStart(DateTime.now())));
