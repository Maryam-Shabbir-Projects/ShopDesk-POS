import 'package:shopdesk/features/sales/domain/sale.dart';

abstract interface class SaleRepository {
  /// Saves the sale and its items in one transaction and, unless
  /// [adjustStock] is false, lowers product stock. Returns the saved sale
  /// with its id and receipt number.
  Future<Sale> create(Sale sale, {bool adjustStock = true});

  /// Sales with createdAt in [from, to), newest first, items included.
  Future<List<Sale>> between(DateTime from, DateTime to);
}
