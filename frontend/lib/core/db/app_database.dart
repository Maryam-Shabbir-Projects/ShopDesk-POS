import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Single SQLite connection for the whole app. Repositories receive it
/// through the constructor so they can be replaced in tests.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'shopdesk.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute("""
CREATE TABLE products(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sku TEXT NOT NULL DEFAULT '',
  barcode TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'General',
  price REAL NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  emoji TEXT NOT NULL DEFAULT '📦',
  image_path TEXT
)""");
        await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
        await db.execute("""
CREATE TABLE sales(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_no TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  customer TEXT NOT NULL DEFAULT '',
  payment TEXT NOT NULL,
  subtotal REAL NOT NULL,
  discount REAL NOT NULL,
  tax_rate REAL NOT NULL,
  tax REAL NOT NULL,
  total REAL NOT NULL
)""");
        await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
        await db.execute("""
CREATE TABLE sale_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  qty INTEGER NOT NULL,
  unit_price REAL NOT NULL
)""");
        await db.execute('CREATE INDEX idx_items_sale ON sale_items(sale_id)');
      },
    );
  }
}
