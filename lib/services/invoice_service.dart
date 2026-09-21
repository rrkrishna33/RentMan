import 'dart:typed_data';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/booking.dart';
import '../models/customer.dart';
import 'settings_service.dart';

/// Builds and shares/prints a billing invoice PDF for a booking.
class InvoiceService {
  static Future<void> generateAndShare({
    required Booking booking,
    required Customer customer,
    required SettingsService settings,
  }) async {
    final bytes = await _buildPdf(booking: booking, customer: customer, settings: settings);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_${customer.name.replaceAll(' ', '_')}_${booking.id}.pdf',
    );
  }

  static Future<void> preview({
    required Booking booking,
    required Customer customer,
    required SettingsService settings,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildPdf(booking: booking, customer: customer, settings: settings),
    );
  }

  static Future<Uint8List> _buildPdf({
    required Booking booking,
    required Customer customer,
    required SettingsService settings,
  }) async {
    // Base14 PDF fonts don't include the ₹ glyph; Noto Sans does.
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    pw.MemoryImage? logo;
    final logoPath = settings.companyLogoPath;
    if (logoPath != null) {
      final logoFile = File(logoPath);
      if (await logoFile.exists()) {
        logo = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    String currency(double value) => '₹${value.toStringAsFixed(0)}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final companyName = settings.companyName.isEmpty ? 'Rental Manager' : settings.companyName;
          const invoiceTitle = 'INVOICE';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logo != null) ...[
                      pw.Container(
                        width: 90,
                        height: 90,
                        decoration: const pw.BoxDecoration(),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 10),
                    ],
                    pw.Text(
                      companyName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
                    ),
                    if (settings.companyAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        settings.companyAddress,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                    if (settings.companyEmail.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        settings.companyEmail,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                    if (settings.companyPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        settings.companyPhone,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                    if (settings.companyGstNumber.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'GST No: ${settings.companyGstNumber}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Divider(height: 12),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Invoice', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Invoice Date: ${_formatDate(DateTime.now())}'),
                      pw.Text('Booking Date: ${_formatDate(booking.bookingDate)}'),
                      pw.Text('Rental Date: ${_formatDate(booking.rentalDate)}'),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      invoiceTitle,
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text(customer.name),
                    if (customer.phone.isNotEmpty) pw.Text(customer.phone),
                    if (customer.address != null && customer.address!.isNotEmpty) pw.Text(customer.address!),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Category', 'Qty'],
                data: booking.items
                    .map((item) => [item.itemName, item.category ?? '-', item.quantity.toString()])
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              ),
              pw.SizedBox(height: 24),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _totalRow('Rent Amount', currency(booking.totalAmount - booking.depositAmount)),
                    _totalRow('Security Deposit', currency(booking.depositAmount)),
                    pw.Divider(),
                    _totalRow('Total Amount', currency(booking.totalAmount), bold: true),
                    pw.Divider(),
                    _totalRow('Paid Amount', currency(booking.paidAmount)),
                    pw.SizedBox(height: 6),
                    _totalRow(
                      'Balance Due',
                      currency(booking.balanceAmount),
                      bold: true,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      booking.balanceAmount == 0 ? 'Status: PAID IN FULL' : 'Status: BALANCE PENDING',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: booking.balanceAmount == 0 ? PdfColors.green700 : PdfColors.orange700,
                      ),
                    ),
                  ],
                ),
              ),
              if (booking.specialNotes != null && booking.specialNotes!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(booking.specialNotes!),
              ],
              pw.Spacer(),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(top: 18),
                child: pw.Text(
                  'Thank you for your business!',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: bold ? 14 : 12);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(width: 140, child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
