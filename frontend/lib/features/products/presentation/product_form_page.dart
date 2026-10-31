import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shopdesk/core/utils/emoji_guess.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';

/// Add or edit a product. Pass [product] to edit, or [initialBarcode] to
/// start a new product from an unknown scanned code.
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.product, this.initialBarcode});
  final Product? product;
  final String? initialBarcode;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late String _emoji;
  String? _image;
  late bool _emojiChosenByUser;
  bool _finding = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final x = widget.product;
    _name = TextEditingController(text: x?.name ?? '');
    _sku = TextEditingController(text: x?.sku ?? '');
    _barcode = TextEditingController(text: x?.barcode ?? widget.initialBarcode ?? '');
    _category = TextEditingController(text: x?.category ?? '');
    _price = TextEditingController(text: x == null ? '' : Fmt.number(x.price));
    _stock = TextEditingController(text: x?.stock.toString() ?? '');
    _emoji = x?.emoji ?? '📦';
    _image = x?.imagePath;
    _emojiChosenByUser = _isEdit;
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _category, _price, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onNameOrCategoryChanged() {
    if (_emojiChosenByUser) return;
    setState(() => _emoji = EmojiGuess.forProduct(_name.text, _category.text));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 600, imageQuality: 80);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(p.join(dir.path, 'product_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await File(picked.path).copy(dest.path);
    if (mounted) setState(() => _image = dest.path);
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _findOnline() async {
    final name = _name.text.trim();
    final code = _barcode.text.trim();
    if (name.isEmpty && code.isEmpty) {
      _toast('Type the product name or barcode first.');
      return;
    }
    setState(() => _finding = true);
    final url = await ref.read(productImageServiceProvider).find(barcode: code, name: name);
    if (!mounted) return;
    setState(() {
      _finding = false;
      if (url != null) _image = url;
    });
    _toast(url != null ? 'Photo found. Check it looks right.' : 'No photo found, or no internet. The icon will be used.');
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      barcode: _barcode.text.trim(),
      category: _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
      price: double.parse(_price.text),
      stock: int.parse(_stock.text),
      emoji: _emoji,
      imagePath: _image,
    );
    await ref.read(productsProvider.notifier).save(product);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final preview = Product(name: _name.text, price: 0, stock: 0, emoji: _emoji, imagePath: _image);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a product name' : null,
              onChanged: (_) => _onNameOrCategoryChanged(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    onChanged: (_) => _onNameOrCategoryChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU'))),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(labelText: 'Barcode', hintText: 'Scan or type barcode'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a price' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock on hand'),
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a number' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Icon or photo', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                ProductAvatar(product: preview, size: 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The icon follows the name. Pick another below, or add a photo.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in {EmojiGuess.forProduct(_name.text, _category.text), ...EmojiGuess.palette})
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: _emoji == e,
                    onSelected: (_) => setState(() {
                      _emoji = e;
                      _emojiChosenByUser = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _choosePhotoSource,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Add photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _finding ? null : _findOnline,
                  icon: _finding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: const Text('Find photo online'),
                ),
                if (_image != null)
                  TextButton(onPressed: () => setState(() => _image = null), child: const Text('Remove photo')),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save product')),
          ],
        ),
      ),
    );
  }
}
