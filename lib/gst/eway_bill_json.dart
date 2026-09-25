/// Builds the e-way bill "bulk generation" JSON that is uploaded on
/// https://ewaybillgst.gov.in -> e-Waybill -> Generate Bulk.
///
/// Field names follow the NIC bulk-upload schema (`version` + `billLists`).
/// Only regular outward supplies (supplyType "O", subSupplyType 1 "Supply",
/// docType "INV", transactionType 1 "Regular") are generated here.
///
/// NOTE: NIC revises this schema from time to time (for example the
/// 1 Aug 2026 Ship-to GSTIN / URP rules for Bill-to-Ship-to cases). If the
/// portal rejects an upload with a schema/version error, compare against the
/// latest "JSON Schema" download on the portal and update [schemaVersion].
library;

import 'dart:convert';

import '../models/sales_invoice.dart';
import 'gst_calculator.dart';
import 'gst_master.dart';

/// Seller (consignor) details, taken from the company profile in Settings.
class EwbSeller {
  final String gstin;
  final String tradeName;
  final String address;
  final String place;
  final String pincode;
  final int stateCode;

  const EwbSeller({
    required this.gstin,
    required this.tradeName,
    required this.address,
    required this.place,
    required this.pincode,
    required this.stateCode,
  });
}

class EwbValidation {
  final List<String> errors;
  final List<String> warnings;
  const EwbValidation(this.errors, this.warnings);
  bool get isValid => errors.isEmpty;
}

class EwayBillJson {
  EwayBillJson._();

  static const schemaVersion = '1.0.0621';

  /// E-way bill is generally mandatory above this consignment value
  /// (some states use a different limit for intra-state movement).
  static const thresholdValue = 50000.0;

  static final _docNoPattern = RegExp(r'^[A-Za-z0-9/-]{1,16}$');
  static final _pincodePattern = RegExp(r'^[1-9][0-9]{5}$');
  static final _vehiclePattern = RegExp(r'^[A-Z0-9]{4,20}$');

  static String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String normalizeVehicleNo(String? v) => (v ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Splits a free-text address into two parts of at most 120 chars each.
  static List<String> splitAddress(String? address) {
    final text = _clean(address?.replaceAll('\n', ', '));
    if (text.length <= 120) return [text, ''];
    var cut = text.lastIndexOf(',', 120);
    if (cut < 20) cut = text.lastIndexOf(' ', 120);
    if (cut < 20) cut = 120;
    final first = text.substring(0, cut).trim();
    var second = text.substring(cut).replaceFirst(RegExp(r'^[,\s]+'), '').trim();
    if (second.length > 120) second = second.substring(0, 120);
    return [first, second];
  }

  static int _hsnAsInt(String hsn) => int.tryParse(hsn.replaceAll(RegExp(r'\D'), '')) ?? 0;

  static EwbValidation validate(SalesInvoice invoice, EwbSeller seller) {
    final errors = <String>[];
    final warnings = <String>[];

    final sellerGstinError = GstMaster.validateGstin(seller.gstin);
    if (sellerGstinError != null) errors.add('Company GSTIN: $sellerGstinError (Settings > Company Profile)');
    if (GstMaster.stateCodeFromGstin(seller.gstin) != seller.stateCode) {
      errors.add('Company state does not match the first two digits of the company GSTIN');
    }
    if (_clean(seller.tradeName).isEmpty) errors.add('Company name is missing in Settings');
    if (!_pincodePattern.hasMatch(seller.pincode)) errors.add('Company PIN code must be 6 digits (Settings)');
    if (_clean(seller.place).isEmpty) errors.add('Company city/place is missing in Settings');

    if (!_docNoPattern.hasMatch(invoice.invoiceNo)) {
      errors.add('Invoice number must be at most 16 characters using letters, digits, / or -');
    }
    if (invoice.invoiceDate.isAfter(DateTime.now())) errors.add('Invoice date cannot be in the future');

    if (invoice.isB2B) {
      final buyerError = GstMaster.validateGstin(invoice.buyerGstin!);
      if (buyerError != null) errors.add('Buyer GSTIN: $buyerError');
      if (GstMaster.normalizeGstin(invoice.buyerGstin!) == GstMaster.normalizeGstin(seller.gstin)) {
        errors.add('Buyer GSTIN cannot be the same as the company GSTIN');
      }
    }
    if (!_pincodePattern.hasMatch(invoice.buyerPincode ?? '')) errors.add('Buyer PIN code must be 6 digits');
    if (_clean(invoice.buyerPlace).isEmpty) errors.add('Buyer city/place is required');
    if (GstMaster.stateByCode(invoice.placeOfSupplyStateCode) == null) errors.add('Place of supply state is not set');

    if (invoice.items.isEmpty) errors.add('Invoice has no items');
    if (invoice.items.length > 250) errors.add('An e-way bill can have at most 250 items');
    for (final item in invoice.items) {
      final digits = item.hsnCode.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 4) errors.add('"${item.name}": HSN code must have at least 4 digits');
    }
    if (invoice.items.isNotEmpty && invoice.items.every((i) => i.hsnCode.startsWith('99'))) {
      errors.add('All items are services (SAC 99xx). E-way bill is only for movement of goods');
    }

    final t = invoice.transport;
    if (t.distanceKm < 0 || t.distanceKm > 4000) errors.add('Distance must be between 0 and 4000 km');
    if (t.transporterId != null && t.transporterId!.isNotEmpty && !GstMaster.isValidGstin(t.transporterId!)) {
      warnings.add('Transporter ID does not look like a valid GSTIN/TRANSIN');
    }
    final vehicle = normalizeVehicleNo(t.vehicleNo);
    if (t.transMode == 1) {
      if (vehicle.isEmpty && (t.transporterId ?? '').isEmpty) {
        warnings.add('No vehicle number or transporter ID: only Part-A will be generated; add Part-B on the portal before movement');
      }
      if (vehicle.isNotEmpty && !_vehiclePattern.hasMatch(vehicle)) errors.add('Vehicle number format is invalid');
    } else {
      if ((t.transDocNo ?? '').isEmpty || t.transDocDate == null) {
        errors.add('Rail/Air/Ship transport needs the transport document number and date');
      }
    }

    final total = invoice.totals.grandTotal;
    if (total < thresholdValue) {
      warnings.add('Invoice value is below ₹50,000; an e-way bill is usually not mandatory (check your state rules)');
    }
    if (t.distanceKm == 0) warnings.add('Distance 0 lets the portal auto-calculate it from the PIN codes');

    return EwbValidation(errors, warnings);
  }

  /// The single-bill map in NIC bulk format.
  static Map<String, dynamic> buildBill(SalesInvoice invoice, EwbSeller seller) {
    final totals = invoice.totals;
    final interState = totals.interState;
    final fromAddr = splitAddress(seller.address);
    final toAddr = splitAddress(invoice.buyerAddress);
    final t = invoice.transport;
    final vehicle = normalizeVehicleNo(t.vehicleNo);

    // Main HSN = HSN carrying the highest taxable value.
    final hsnValues = <String, double>{};
    for (var i = 0; i < invoice.items.length; i++) {
      final hsn = invoice.items[i].hsnCode;
      hsnValues[hsn] = (hsnValues[hsn] ?? 0) + totals.lines[i].taxableValue;
    }
    final mainHsn = hsnValues.entries.isEmpty
        ? ''
        : hsnValues.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final itemList = <Map<String, dynamic>>[];
    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      final line = totals.lines[i];
      itemList.add({
        'itemNo': i + 1,
        'productName': _clean(item.name),
        'productDesc': _clean(item.name),
        'hsnCode': _hsnAsInt(item.hsnCode),
        'quantity': item.quantity,
        'qtyUnit': item.unit,
        'taxableAmount': line.taxableValue,
        'sgstRate': interState ? 0 : item.gstRate / 2,
        'cgstRate': interState ? 0 : item.gstRate / 2,
        'igstRate': interState ? item.gstRate : 0,
        'cessRate': 0,
        'cessNonAdvol': 0,
      });
    }

    return {
      'userGstin': GstMaster.normalizeGstin(seller.gstin),
      'supplyType': 'O',
      'subSupplyType': 1,
      'subSupplyDesc': '',
      'docType': 'INV',
      'docNo': invoice.invoiceNo,
      'docDate': formatDate(invoice.invoiceDate),
      'fromGstin': GstMaster.normalizeGstin(seller.gstin),
      'fromTrdName': _clean(seller.tradeName),
      'fromAddr1': fromAddr[0],
      'fromAddr2': fromAddr[1],
      'fromPlace': _clean(seller.place),
      'fromPincode': int.tryParse(seller.pincode) ?? 0,
      'fromStateCode': seller.stateCode,
      'actualFromStateCode': seller.stateCode,
      'toGstin': invoice.isB2B ? GstMaster.normalizeGstin(invoice.buyerGstin!) : 'URP',
      'toTrdName': _clean(invoice.buyerName),
      'toAddr1': toAddr[0],
      'toAddr2': toAddr[1],
      'toPlace': _clean(invoice.buyerPlace),
      'toPincode': int.tryParse(invoice.buyerPincode ?? '') ?? 0,
      'toStateCode': invoice.placeOfSupplyStateCode,
      'actualToStateCode': invoice.placeOfSupplyStateCode,
      'transactionType': 1,
      'dispatchFromGSTIN': '',
      'dispatchFromTradeName': '',
      'shipToGSTIN': '',
      'shipToTradeName': '',
      'totalValue': totals.taxableValue,
      'cgstValue': totals.cgst,
      'sgstValue': totals.sgst,
      'igstValue': totals.igst,
      'cessValue': 0,
      'cessNonAdvolValue': 0,
      'otherValue': totals.roundOff,
      'totInvValue': totals.grandTotal,
      'transMode': t.transMode,
      'transDistance': t.distanceKm.toString(),
      'transporterName': _clean(t.transporterName),
      'transporterId': (t.transporterId ?? '').trim().toUpperCase(),
      'transDocNo': _clean(t.transDocNo),
      'transDocDate': t.transDocDate == null ? '' : formatDate(t.transDocDate!),
      'vehicleNo': vehicle,
      'vehicleType': 'R',
      'mainHsnCode': _hsnAsInt(mainHsn),
      'itemList': itemList,
    };
  }

  /// Full upload file for one or more invoices.
  static Map<String, dynamic> buildFile(List<SalesInvoice> invoices, EwbSeller seller) => {
        'version': schemaVersion,
        'billLists': invoices.map((i) => buildBill(i, seller)).toList(),
      };

  static String encode(List<SalesInvoice> invoices, EwbSeller seller) =>
      const JsonEncoder.withIndent('  ').convert(buildFile(invoices, seller));

  /// Round-trip sanity: totInvValue must equal the sum of its parts.
  static bool totalsConsistent(Map<String, dynamic> bill) {
    final sum = (bill['totalValue'] as num) +
        (bill['cgstValue'] as num) +
        (bill['sgstValue'] as num) +
        (bill['igstValue'] as num) +
        (bill['cessValue'] as num) +
        (bill['cessNonAdvolValue'] as num) +
        (bill['otherValue'] as num);
    return (round2(sum.toDouble()) - (bill['totInvValue'] as num)).abs() < 0.01;
  }
}
