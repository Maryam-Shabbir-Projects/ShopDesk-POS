import 'package:shopdesk/core/db/app_database.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/domain/product_repository.dart';
import 'package:sqflite/sqflite.dart';

class SqliteProductRepository implements ProductRepository {
  SqliteProductRepository(this._db);
  final AppDatabase _db;

  static const _table = 'products';

  @override
  Future<List<Product>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(_table, orderBy: 'name COLLATE NOCASE');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> upsert(Product product) async {
    final db = await _db.database;
    final row = _toRow(product);
    if (product.id == null) return db.insert(_table, row);
    await db.update(_table, row, where: 'id = ?', whereArgs: [product.id]);
    return product.id!;
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> adjustStock(int id, int delta) async {
    final db = await _db.database;
    await db.rawUpdate('UPDATE products SET stock = MAX(stock + ?, 0) WHERE id = ?', [delta, id]);
  }

  @override
  Future<int> count() async {
    final db = await _db.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
  }

  Product _fromRow(Map<String, Object?> r) => Product(
        id: r['id'] as int,
        name: r['name'] as String,
        sku: r['sku'] as String,
        barcode: r['barcode'] as String,
        category: r['category'] as String,
        price: (r['price'] as num).toDouble(),
        stock: r['stock'] as int,
        emoji: r['emoji'] as String,
        imagePath: r['image_path'] as String?,
      );

  Map<String, Object?> _toRow(Product p) => {
        'name': p.name,
        'sku': p.sku,
        'barcode': p.barcode,
        'category': p.category,
        'price': p.price,
        'stock': p.stock,
        'emoji': p.emoji,
        'image_path': p.imagePath,
      };
}
