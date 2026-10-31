class Currency {
  const Currency(this.code, this.symbol);
  final String code;
  final String symbol;
}

abstract final class AppConstants {
  static const appName = 'ShopDesk';
  static const lowStockThreshold = 10;
  static const defaultTaxRate = 8.0;
  static const defaultCurrency = 'USD';
  static const currencies = <Currency>[
    Currency('USD', r'$'),
    Currency('EUR', '€'),
    Currency('GBP', '£'),
    Currency('PKR', 'Rs '),
    Currency('INR', '₹'),
    Currency('AED', 'AED '),
    Currency('SAR', 'SAR '),
  ];
}
