import 'dart:math';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';

enum ForecastAdvice { outOfStock, reorder, notSelling, ok }

class ProductForecast {
  const ProductForecast({
    required this.product,
    required this.sold,
    required this.previousSold,
    required this.perDay,
    required this.daysLeft,
    required this.suggestedOrder,
    required this.advice,
  });

  final Product product;
  final int sold;
  final int previousSold;
  final double perDay;

  /// Null when nothing sold, so the run-out date cannot be estimated.
  final double? daysLeft;
  final int suggestedOrder;
  final ForecastAdvice advice;

  /// Change versus the previous equal period, or null with no baseline.
  int? get trendPercent =>
      previousSold == 0 ? null : (((sold - previousSold) / previousSold) * 100).round();
}

/// Looks at the last [days] days and the [days] before that to rank
/// products and estimate when each will run out. Pure and unit tested.
abstract final class ForecastService {
  static const horizonDays = 14;
  static const reorderBelowDays = 7;

  static List<ProductForecast> build({
    required List<Product> products,
    required List<Sale> sales,
    required int days,
    required DateTime now,
  }) {
    final currentStart = now.subtract(Duration(days: days));
    final previousStart = now.subtract(Duration(days: days * 2));
    final current = <int, int>{};
    final previous = <int, int>{};

    for (final sale in sales) {
      final bucket = sale.createdAt.isAfter(currentStart)
          ? current
          : sale.createdAt.isAfter(previousStart)
              ? previous
              : null;
      if (bucket == null) continue;
      for (final item in sale.items) {
        bucket[item.productId] = (bucket[item.productId] ?? 0) + item.qty;
      }
    }

    final result = products.map((p) {
      final sold = current[p.id] ?? 0;
      final perDay = sold / days;
      final daysLeft = perDay > 0 ? p.stock / perDay : null;
      final need = perDay > 0 ? max(0, (perDay * horizonDays).ceil() - p.stock) : 0;
      final advice = p.stock <= 0
          ? ForecastAdvice.outOfStock
          : (daysLeft != null && daysLeft < reorderBelowDays)
              ? ForecastAdvice.reorder
              : sold == 0
                  ? ForecastAdvice.notSelling
                  : ForecastAdvice.ok;
      return ProductForecast(
        product: p,
        sold: sold,
        previousSold: previous[p.id] ?? 0,
        perDay: perDay,
        daysLeft: daysLeft,
        suggestedOrder: need,
        advice: advice,
      );
    }).toList();

    result.sort((a, b) => b.sold.compareTo(a.sold));
    return result;
  }
}
