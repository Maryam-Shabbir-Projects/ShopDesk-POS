import 'package:shopdesk/core/constants/app_constants.dart';

enum StockStatus { inStock, low, out }

class Product {
  const Product({
    this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.category = 'General',
    required this.price,
    required this.stock,
    this.emoji = '📦',
    this.imagePath,
  });

  final int? id;
  final String name;
  final String sku;
  final String barcode;
  final String category;
  final String emoji;
  final double price;
  final int stock;

  /// A local file path or an http(s) URL. Null means "use the emoji".
  final String? imagePath;

  StockStatus get status => stock <= 0
      ? StockStatus.out
      : stock <= AppConstants.lowStockThreshold
          ? StockStatus.low
          : StockStatus.inStock;

  bool matchesCode(String code) {
    final c = code.trim().toLowerCase();
    return c.isNotEmpty && (barcode.toLowerCase() == c || sku.toLowerCase() == c);
  }

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? emoji,
    double? price,
    int? stock,
    String? imagePath,
    bool clearImage = false,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        category: category ?? this.category,
        emoji: emoji ?? this.emoji,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      );
}
