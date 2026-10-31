import 'package:shopdesk/core/db/app_database.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';
import 'package:shopdesk/features/sales/domain/sale_repository.dart';

class SqliteSaleRepository implements SaleRepository {
  SqliteSaleRepository(this._db);
  final AppDatabase _db;

  @override
  Future<Sale> create(Sale sale, {bool adjustStock = true}) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final id = await txn.insert('sales', {
        'receipt_no': 'pending',
        'created_at': sale.createdAt.millisecondsSinceEpoch,
        'customer': sale.customer,
        'payment': sale.payment.name,
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'tax_rate': sale.taxRate,
        'tax': sale.tax,
        'total': sale.total,
      });
      final receiptNo = 'R-${1000 + id}';
      await txn.update('sales', {'receipt_no': receiptNo}, where: 'id = ?', whereArgs: [id]);
      for (final item in sale.items) {
        await txn.insert('sale_items', {
          'sale_id': id,
          'product_id': item.productId,
          'name': item.name,
          'emoji': item.emoji,
          'qty': item.qty,
          'unit_price': item.unitPrice,
        });
        if (adjustStock) {
          await txn.rawUpdate(
            'UPDATE products SET stock = MAX(stock - ?, 0) WHERE id = ?',
            [item.qty, item.productId],
          );
        }
      }
      return sale.copyWith(id: id, receiptNo: receiptNo);
    });
  }

  @override
  Future<List<Sale>> between(DateTime from, DateTime to) async {
    final db = await _db.database;
    final rows = await db.query(
      'sales',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
    );
    if (rows.isEmpty) return const [];

    final ids = rows.map((r) => r['id'] as int).toList();
    final marks = List.filled(ids.length, '?').join(',');
    final itemRows = await db.rawQuery('SELECT * FROM sale_items WHERE sale_id IN ($marks)', ids);
    final bySale = <int, List<SaleItem>>{};
    for (final r in itemRows) {
      (bySale[r['sale_id'] as int] ??= []).add(SaleItem(
        productId: r['product_id'] as int,
        name: r['name'] as String,
        emoji: r['emoji'] as String,
        qty: r['qty'] as int,
        unitPrice: (r['unit_price'] as num).toDouble(),
      ));
    }
    return rows
        .map((r) => Sale(
              id: r['id'] as int,
              receiptNo: r['receipt_no'] as String,
              createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
              customer: r['customer'] as String,
              payment: PaymentMethod.values.byName(r['payment'] as String),
              subtotal: (r['subtotal'] as num).toDouble(),
              discount: (r['discount'] as num).toDouble(),
              taxRate: (r['tax_rate'] as num).toDouble(),
              tax: (r['tax'] as num).toDouble(),
              total: (r['total'] as num).toDouble(),
              items: bySale[r['id'] as int] ?? const [],
            ))
        .toList();
  }
}
