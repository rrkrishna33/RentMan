import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../gst/eway_bill_json.dart';
import '../models/sales_invoice.dart';

/// Writes the e-way bill bulk-upload JSON to a file and opens the share sheet
/// so it can be saved to Files/Drive or sent to the computer used for upload.
class EwayBillExportService {
  EwayBillExportService._();

  static const portalUrl = 'https://ewaybillgst.gov.in';

  static Future<File> writeFile(SalesInvoice invoice, EwbSeller seller) async {
    final dir = await getTemporaryDirectory();
    final safeNo = invoice.invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_');
    final file = File('${dir.path}/EWB_$safeNo.json');
    await file.writeAsString(EwayBillJson.encode([invoice], seller));
    return file;
  }

  static Future<void> share(SalesInvoice invoice, EwbSeller seller) async {
    final file = await writeFile(invoice, seller);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'E-way bill JSON for invoice ${invoice.invoiceNo}',
    );
  }
}
