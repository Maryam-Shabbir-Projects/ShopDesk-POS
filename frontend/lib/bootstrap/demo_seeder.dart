import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopdesk/core/db/app_database.dart';
import 'package:shopdesk/features/products/data/sqlite_product_repository.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/sales/data/sqlite_sale_repository.dart';
import 'package:shopdesk/features/sales/domain/pricing_service.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';

/// Fills an empty database with 12 products and 60 days of sample sales so
/// the dashboard and predictor have something to show. Delete this file and
/// its call in main.dart for a production build.
class DemoSeeder {
  DemoSeeder(this._db, this._prefs);
  final AppDatabase _db;
  final SharedPreferences _prefs;

  static const _flag = 'demo_seeded';
  static const _customers = ['', '', '', 'Ayesha K.', 'Bilal R.', 'Sara M.', 'Omar H.'];

  // name, sku, category, price, stock, emoji, popularity weight
  static const _catalog = <(String, String, String, double, int, String, int)>[
    ('Whole milk 1L', 'DRY-001', 'Dairy', 1.8, 42, '🥛', 9),
    ('Free-range eggs x12', 'DRY-002', 'Dairy', 3.6, 8, '🥚', 6),
    ('Sourdough loaf', 'BKR-001', 'Bakery', 4.2, 15, '🍞', 7),
    ('Butter croissant', 'BKR-002', 'Bakery', 2.1, 0, '🥐', 4),
    ('Bananas 1kg', 'PRD-001', 'Produce', 1.9, 31, '🍌', 8),
    ('Tomatoes 500g', 'PRD-002', 'Produce', 2.4, 6, '🍅', 2),
    ('Orange juice 1L', 'DRK-001', 'Drinks', 3.2, 24, '🧃', 5),
    ('Sparkling water', 'DRK-002', 'Drinks', 1.1, 60, '💧', 9),
    ('Basmati rice 5kg', 'GRC-001', 'Grocery', 11.5, 12, '🍚', 1),
    ('Olive oil 500ml', 'GRC-002', 'Grocery', 7.8, 9, '🫒', 1),
    ('Dark chocolate', 'SNK-001', 'Snacks', 2.9, 37, '🍫', 6),
    ('Salted crisps', 'SNK-002', 'Snacks', 1.6, 48, '🥔', 7),
  ];

  Future<void> seedIfNeeded() async {
    if (_prefs.getBool(_flag) ?? false) return;
    final products = SqliteProductRepository(_db);
    final sales = SqliteSaleRepository(_db);
    if (await products.count() > 0) {
      await _prefs.setBool(_flag, true);
      return;
    }

    final saved = <Product>[];
    final pool = <int>[];
    for (var i = 0; i < _catalog.length; i++) {
      final c = _catalog[i];
      final draft = Product(
        name: c.$1,
        sku: c.$2,
        category: c.$3,
        price: c.$4,
        stock: c.$5,
        emoji: c.$6,
        barcode: '890100${(i + 1).toString().padLeft(6, '0')}',
      );
      final id = await products.upsert(draft);
      saved.add(draft.copyWith(id: id));
      pool.addAll(List.filled(c.$7, i));
    }

    // Small deterministic generator so the demo data is the same every time.
    var seed = 7;
    double rnd() {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    }

    final now = DateTime.now();
    final taxRate = _prefs.getDouble('tax_rate') ?? 8.0;
    for (var d = 59; d >= 0; d--) {
      final orders = d == 0 ? 3 : 4 + (rnd() * 5).floor();
      for (var k = 0; k < orders; k++) {
        final hour = d == 0 ? 8 + (rnd() * 2).floor() : 9 + (rnd() * 11).floor();
        final when = DateTime(now.year, now.month, now.day - d, hour, (rnd() * 60).floor());
        final qtyById = <int, int>{};
        final lines = 1 + (rnd() * 4).floor();
        for (var j = 0; j < lines; j++) {
          final p = saved[pool[(rnd() * pool.length).floor()]];
          qtyById[p.id!] = (qtyById[p.id!] ?? 0) + 1 + (rnd() * 2).floor();
        }
        final items = [
          for (final e in qtyById.entries)
            () {
              final p = saved.firstWhere((x) => x.id == e.key);
              return SaleItem(productId: p.id!, name: p.name, emoji: p.emoji, qty: e.value, unitPrice: p.price);
            }(),
        ];
        final t = PricingService.calculate(
          subtotal: items.fold(0.0, (a, i) => a + i.lineTotal),
          discountPct: 0,
          taxRate: taxRate,
        );
        await sales.create(
          Sale(
            createdAt: when,
            customer: _customers[(rnd() * _customers.length).floor()],
            payment: PaymentMethod.values[(rnd() * 3).floor()],
            subtotal: t.subtotal,
            discount: t.discount,
            taxRate: t.taxRate,
            tax: t.tax,
            total: t.total,
            items: items,
          ),
          adjustStock: false, // history only: keep the stock levels above
        );
      }
    }
    await _prefs.setBool(_flag, true);
  }
}
