import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shopdesk/features/products/domain/product.dart';

/// Shows the product photo when there is one, otherwise its emoji icon.
/// A photo that fails to load (for example offline) falls back to the emoji.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({super.key, required this.product, this.size = 44});
  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Center(child: Text(product.emoji, style: TextStyle(fontSize: size * 0.55)));
    final path = product.imagePath;
    Widget content = fallback;
    if (path != null && path.isNotEmpty) {
      content = path.startsWith('http')
          ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
          : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Container(width: size, height: size, color: scheme.surfaceContainerHighest, child: content),
    );
  }
}
