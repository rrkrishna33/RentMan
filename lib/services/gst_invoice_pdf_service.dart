import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../gst/amount_in_words.dart';
import '../gst/gst_calculator.dart';
import '../gst/gst_master.dart';
import '../models/sales_invoice.dart';
import 'settings_service.dart';

/// Builds the GST "Tax Invoice" PDF for a sales invoice.
class GstInvoicePdfService {
  GstInvoicePdfService._();

  static String _fileName(SalesInvoice invoice) =>
      'TaxInvoice_${invoice.invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_')}.pdf';

  static Future<void> share(SalesInvoice invoice, SettingsService settings) async {
    final bytes = await build(invoice, settings);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(invoice));
  }

  static Future<void> printOrPreview(SalesInvoice invoice, SettingsService settings) async {
    await Printing.layoutPdf(
      name: _fileName(invoice),
      onLayout: (_) => build(invoice, settings),
    );
  }

  static String _money(double v) {
    final negative = v < 0;
    final fixed = v.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    var whole = parts[0];
    // Indian digit grouping: 12,34,567.89
    if (whole.length > 3) {
      final last3 = whole.substring(whole.length - 3);
      var rest = whole.substring(0, whole.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      whole = '${groups.join(',')},$last3';
    }
    return '${negative ? '-' : ''}$whole.${parts[1]}';
  }

  static String _qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(3);

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Future<Uint8List> build(SalesInvoice invoice, SettingsService settings) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    pw.MemoryImage? logo;
    final logoPath = settings.companyLogoPath;
    if (logoPath != null) {
      final file = File(logoPath);
      if (await file.exists()) logo = pw.MemoryImage(await file.readAsBytes());
    }

    final totals = invoice.totals;
    final inter = totals.interState;
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

    const small = pw.TextStyle(fontSize: 8.5);
    final smallBold = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);
    final label = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);
    const border = pw.TableBorder(
      top: pw.BorderSide(width: 0.5),
      bottom: pw.BorderSide(width: 0.5),
      left: pw.BorderSide(width: 0.5),
      right: pw.BorderSide(width: 0.5),
      horizontalInside: pw.BorderSide(width: 0.3, color: PdfColors.grey500),
      verticalInside: pw.BorderSide(width: 0.3, color: PdfColors.grey500),
    );

    pw.Widget cell(String text, {pw.TextStyle? style, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(text, style: style ?? small, textAlign: align),
        );

    final companyName = settings.companyName.isEmpty ? 'Company Name' : settings.companyName;
    final sellerState = GstMaster.stateLabel(invoice.sellerStateCode);
    final posState = GstMaster.stateLabel(invoice.placeOfSupplyStateCode);

    // ---------- Items table ----------
    final itemHeaders = [
      '#', 'Description', 'HSN/SAC', 'Qty', 'Rate', 'Disc %', 'Taxable',
      if (inter) 'IGST' else 'CGST',
      if (!inter) 'SGST',
      'Amount',
    ];
    final itemRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: itemHeaders.map((h) => cell(h, style: smallBold, align: pw.TextAlign.center)).toList(),
      ),
    ];
    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      final line = totals.lines[i];
      final rateLabel = GstCalculator.formatRate(inter ? item.gstRate : item.gstRate / 2);
      itemRows.add(pw.TableRow(children: [
        cell('${i + 1}', align: pw.TextAlign.center),
        cell(item.name),
        cell(item.hsnCode, align: pw.TextAlign.center),
        cell('${_qty(item.quantity)} ${item.unit}', align: pw.TextAlign.right),
        cell(_money(item.rate) + (item.priceIncludesTax ? '*' : ''), align: pw.TextAlign.right),
        cell(item.discountPercent == 0 ? '-' : GstCalculator.formatRate(item.discountPercent),
            align: pw.TextAlign.right),
        cell(_money(line.taxableValue), align: pw.TextAlign.right),
        if (inter)
          cell('${_money(line.igst)}\n@$rateLabel%', align: pw.TextAlign.right)
        else
          cell('${_money(line.cgst)}\n@$rateLabel%', align: pw.TextAlign.right),
        if (!inter) cell('${_money(line.sgst)}\n@$rateLabel%', align: pw.TextAlign.right),
        cell(_money(line.lineTotal), align: pw.TextAlign.right),
      ]));
    }

    final itemWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(18),
      1: const pw.FlexColumnWidth(3.2),
      2: const pw.FixedColumnWidth(46),
      3: const pw.FixedColumnWidth(44),
      4: const pw.FixedColumnWidth(50),
      5: const pw.FixedColumnWidth(30),
      6: const pw.FixedColumnWidth(56),
      7: const pw.FixedColumnWidth(48),
    };
    if (inter) {
      itemWidths[8] = const pw.FixedColumnWidth(58);
    } else {
      itemWidths[8] = const pw.FixedColumnWidth(48);
      itemWidths[9] = const pw.FixedColumnWidth(58);
    }

    // ---------- HSN summary ----------
    final hsnHeaders = ['HSN/SAC', 'Taxable', if (inter) 'IGST' else 'CGST', if (!inter) 'SGST', 'Total Tax'];
    final hsnRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: hsnHeaders.map((h) => cell(h, style: smallBold, align: pw.TextAlign.center)).toList(),
      ),
      ...totals.hsnSummary.map((row) {
        final r = GstCalculator.formatRate(inter ? row.gstRate : row.gstRate / 2);
        return pw.TableRow(children: [
          cell(row.hsnCode, align: pw.TextAlign.center),
          cell(_money(row.taxableValue), align: pw.TextAlign.right),
          if (inter) cell('${_money(row.igst)} @$r%', align: pw.TextAlign.right),
          if (!inter) cell('${_money(row.cgst)} @$r%', align: pw.TextAlign.right),
          if (!inter) cell('${_money(row.sgst)} @$r%', align: pw.TextAlign.right),
          cell(_money(row.totalTax), align: pw.TextAlign.right),
        ]);
      }),
    ];

    pw.Widget totalLine(String name, String value, {bool strong = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(name, style: strong ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10) : small)),
            pw.Text(value, style: strong ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10) : small),
          ]),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Text('${invoice.invoiceNo} (continued)', style: label),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('This is a computer generated invoice.', style: label),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: label),
          ],
        ),
        build: (context) => [
          // Title row
          pw.Center(
            child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          ),
          pw.SizedBox(height: 8),
          // Seller + invoice meta
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null) ...[
                  pw.SizedBox(width: 56, height: 56, child: pw.Image(logo, fit: pw.BoxFit.contain)),
                  pw.SizedBox(width: 10),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(companyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      if (settings.companyAddress.isNotEmpty) pw.Text(settings.companyAddress, style: small),
                      if (settings.companyCity.isNotEmpty || settings.companyPincode.isNotEmpty)
                        pw.Text('${settings.companyCity} ${settings.companyPincode}'.trim(), style: small),
                      if (settings.companyPhone.isNotEmpty) pw.Text('Phone: ${settings.companyPhone}', style: small),
                      if (settings.companyEmail.isNotEmpty) pw.Text('Email: ${settings.companyEmail}', style: small),
                      if (settings.companyGstNumber.isNotEmpty)
                        pw.Text('GSTIN: ${settings.companyGstNumber}', style: smallBold),
                      pw.Text('State: $sellerState', style: small),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Invoice No: ${invoice.invoiceNo}', style: smallBold),
                    pw.Text('Invoice Date: ${_date(invoice.invoiceDate)}', style: small),
                    pw.Text('Place of Supply: $posState', style: small),
                    pw.Text('Reverse Charge: No', style: small),
                    if (invoice.hasEwayBill) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('E-Way Bill No: ${invoice.ewbNo}', style: smallBold),
                      if (invoice.ewbDate != null) pw.Text('EWB Date: ${_date(invoice.ewbDate!)}', style: small),
                    ],
                    if ((invoice.transport.vehicleNo ?? '').isNotEmpty)
                      pw.Text('Vehicle No: ${invoice.transport.vehicleNo}', style: small),
                  ],
                ),
              ],
            ),
          ),
          // Buyer
          pw.Container(
            width: double.infinity,
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5), bottom: pw.BorderSide(width: 0.5)),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bill To', style: label),
                pw.Text(invoice.buyerName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if ((invoice.buyerAddress ?? '').isNotEmpty) pw.Text(invoice.buyerAddress!, style: small),
                if ((invoice.buyerPlace ?? '').isNotEmpty || (invoice.buyerPincode ?? '').isNotEmpty)
                  pw.Text('${invoice.buyerPlace ?? ''} ${invoice.buyerPincode ?? ''}'.trim(), style: small),
                if ((invoice.buyerPhone ?? '').isNotEmpty) pw.Text('Phone: ${invoice.buyerPhone}', style: small),
                pw.Text(invoice.isB2B ? 'GSTIN: ${invoice.buyerGstin}' : 'GSTIN: Unregistered', style: smallBold),
                pw.Text('State: $posState', style: small),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(border: border, columnWidths: itemWidths, children: itemRows),
          if (invoice.items.any((i) => i.priceIncludesTax))
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text('* Rate inclusive of GST', style: label),
            ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Table(border: border, children: hsnRows),
                    pw.SizedBox(height: 8),
                    pw.Text('Amount in words', style: label),
                    pw.Text(amountInWords(totals.grandTotal), style: smallBold),
                    if ((invoice.notes ?? '').isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('Notes', style: label),
                      pw.Text(invoice.notes!, style: small),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                  child: pw.Column(children: [
                    totalLine('Taxable Value', _money(totals.taxableValue)),
                    if (inter) totalLine('IGST', _money(totals.igst)),
                    if (!inter) totalLine('CGST', _money(totals.cgst)),
                    if (!inter) totalLine('SGST', _money(totals.sgst)),
                    if (totals.roundOff != 0) totalLine('Round Off', _money(totals.roundOff)),
                    pw.Divider(height: 6, thickness: 0.5),
                    totalLine('Invoice Total', '₹${_money(totals.grandTotal)}', strong: true),
                    if (invoice.paidAmount > 0) ...[
                      totalLine('Received', _money(invoice.paidAmount)),
                      totalLine('Balance Due', _money(invoice.balanceAmount), strong: true),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Thank you for your business!', style: small),
              pw.Column(children: [
                pw.Text('For $companyName', style: smallBold),
                pw.SizedBox(height: 28),
                pw.Text('Authorised Signatory', style: small),
              ]),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }
}
