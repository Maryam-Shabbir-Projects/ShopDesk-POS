enum PaymentMethod {
  cash,
  card,
  wallet;

  String get label => name[0].toUpperCase() + name.substring(1);
}

class SaleItem {
  const SaleItem({
    required this.productId,
    required this.name,
    required this.emoji,
    required this.qty,
    required this.unitPrice,
  });

  final int productId;
  final String name;
  final String emoji;
  final int qty;
  final double unitPrice;

  double get lineTotal => unitPrice * qty;
}

class Sale {
  const Sale({
    this.id,
    this.receiptNo = '',
    required this.createdAt,
    this.customer = '',
    required this.payment,
    required this.subtotal,
    required this.discount,
    required this.taxRate,
    required this.tax,
    required this.total,
    required this.items,
  });

  final int? id;
  final String receiptNo;
  final DateTime createdAt;
  final String customer;
  final PaymentMethod payment;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double tax;
  final double total;
  final List<SaleItem> items;

  int get itemCount => items.fold(0, (a, i) => a + i.qty);

  Sale copyWith({int? id, String? receiptNo}) => Sale(
        id: id ?? this.id,
        receiptNo: receiptNo ?? this.receiptNo,
        createdAt: createdAt,
        customer: customer,
        payment: payment,
        subtotal: subtotal,
        discount: discount,
        taxRate: taxRate,
        tax: tax,
        total: total,
        items: items,
      );
}
