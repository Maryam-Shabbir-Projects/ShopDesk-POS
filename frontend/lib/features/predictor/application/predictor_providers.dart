import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/features/predictor/domain/forecast_service.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/sales/application/sales_providers.dart';
import 'package:shopdesk/features/sales/domain/date_range.dart';

/// 7 (last week) or 30 (last month).
final forecastDaysProvider = StateProvider<int>((ref) => 7);

final forecastProvider = FutureProvider.autoDispose<List<ProductForecast>>((ref) async {
  final days = ref.watch(forecastDaysProvider);
  final products = await ref.watch(productsProvider.future);
  final now = DateTime.now();
  final range = DateRange(
    now.subtract(Duration(days: days * 2)),
    now.add(const Duration(minutes: 1)),
  );
  final sales = await ref.watch(salesInRangeProvider(range).future);
  return ForecastService.build(products: products, sales: sales, days: days, now: now);
});
