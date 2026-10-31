import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopdesk/core/constants/app_constants.dart';
import 'package:shopdesk/core/utils/formatters.dart';

/// Overridden in main() with the real instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

class SettingsState {
  const SettingsState({
    required this.currencyCode,
    required this.taxRate,
    required this.shopName,
    required this.receiptFooter,
  });

  final String currencyCode;
  final double taxRate;
  final String shopName;
  final String receiptFooter;

  String get symbol => AppConstants.currencies
      .firstWhere((c) => c.code == currencyCode, orElse: () => AppConstants.currencies.first)
      .symbol;

  String money(double value) => Fmt.money(value, symbol);

  SettingsState copyWith({String? currencyCode, double? taxRate, String? shopName, String? receiptFooter}) =>
      SettingsState(
        currencyCode: currencyCode ?? this.currencyCode,
        taxRate: taxRate ?? this.taxRate,
        shopName: shopName ?? this.shopName,
        receiptFooter: receiptFooter ?? this.receiptFooter,
      );
}

class SettingsController extends Notifier<SettingsState> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  SettingsState build() => SettingsState(
        currencyCode: _prefs.getString('currency') ?? AppConstants.defaultCurrency,
        taxRate: _prefs.getDouble('tax_rate') ?? AppConstants.defaultTaxRate,
        shopName: _prefs.getString('shop_name') ?? AppConstants.appName,
        receiptFooter: _prefs.getString('receipt_footer') ?? 'Thank you for shopping with us',
      );

  Future<void> save(SettingsState next) async {
    state = next;
    await _prefs.setString('currency', next.currencyCode);
    await _prefs.setDouble('tax_rate', next.taxRate);
    await _prefs.setString('shop_name', next.shopName);
    await _prefs.setString('receipt_footer', next.receiptFooter);
  }

  Future<void> setCurrency(String code) => save(state.copyWith(currencyCode: code));
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
