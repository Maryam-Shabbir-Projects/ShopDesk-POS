import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/features/sales/application/sales_providers.dart';
import 'package:shopdesk/features/sales/domain/date_range.dart';

class DayTotal {
  const DayTotal({required this.date, required this.total, required this.orders, required this.items});
  final DateTime date;
  final double total;
  final int orders;
  final int items;
}

/// Sales for the last 7 days, oldest first. The last entry is today.
final weeklySalesProvider = FutureProvider.autoDispose<List<DayTotal>>((ref) async {
  final today = dayStart(DateTime.now());
  final from = DateTime(today.year, today.month, today.day - 6);
  final to = DateTime(today.year, today.month, today.day + 1);
  final sales = await ref.watch(salesInRangeProvider(DateRange(from, to)).future);
  return List.generate(7, (i) {
    final day = DateTime(from.year, from.month, from.day + i);
    final ofDay = sales.where((s) => dayStart(s.createdAt) == day).toList();
    return DayTotal(
      date: day,
      total: ofDay.fold(0.0, (a, s) => a + s.total),
      orders: ofDay.length,
      items: ofDay.fold(0, (a, s) => a + s.itemCount),
    );
  });
});
