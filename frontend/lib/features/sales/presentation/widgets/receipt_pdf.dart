import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

/// 80 mm thermal-style receipt. The default PDF fonts have no emoji or
/// currency symbols, so amounts use the currency code (e.g. 12.50 USD).
abstract final class ReceiptPdf {
  static Future<Uint8List> build(Sale sale, SettingsState settings) {
    String money(double v) => '${v.toStringAsFixed(2)} ${settings.currencyCode}';

    pw.Widget row(String left, String right, {bool bold = false}) {
      final style = pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Expanded(child: pw.Text(left, style: style)), pw.Text(right, style: style)],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(settings.shopName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Receipt ${sale.receiptNo}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(Fmt.dateTime.format(sale.createdAt), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            if (sale.customer.isNotEmpty)
              pw.Text('Customer: ${sale.customer}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            pw.Divider(),
            for (final i in sale.items) row('${i.qty} x ${i.name}', money(i.lineTotal)),
            pw.Divider(),
            row('Subtotal', money(sale.subtotal)),
            if (sale.discount > 0) row('Discount', '-${money(sale.discount)}'),
            row('Tax (${Fmt.number(sale.taxRate)}%)', money(sale.tax)),
            row('Total (${sale.payment.label})', money(sale.total), bold: true),
            pw.SizedBox(height: 10),
            if (settings.receiptFooter.isNotEmpty)
              pw.Text(settings.receiptFooter, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
