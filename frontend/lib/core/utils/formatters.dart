import 'package:intl/intl.dart';

double round2(double v) => (v * 100).roundToDouble() / 100;

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

abstract final class Fmt {
  static String money(double v, String symbol) =>
      NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(v);
  static final DateFormat date = DateFormat.yMMMd();
  static final DateFormat dateTime = DateFormat.yMMMd().add_jm();
  static final DateFormat weekday = DateFormat.E();
  static String number(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
