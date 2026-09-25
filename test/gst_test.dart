import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/gst/amount_in_words.dart';
import 'package:rental_app/gst/eway_bill_json.dart';
import 'package:rental_app/gst/gst_calculator.dart';
import 'package:rental_app/gst/gst_master.dart';
import 'package:rental_app/models/sales_invoice.dart';
import 'package:rental_app/services/billing_provider.dart';

// Structurally valid GSTINs (check digits verified independently).
const sellerGstin = '33AABCT1332L1ZL'; // Tamil Nadu
const buyerGstinKa = '29AAGCB7383J1Z4'; // Karnataka

const seller = EwbSeller(
  gstin: sellerGstin,
  tradeName: 'GellSoft Traders',
  address: '12, Main Road, Anna Nagar',
  place: 'Chennai',
  pincode: '600040',
  stateCode: 33,
);

SalesInvoice _invoice({
  String? buyerGstin,
  int pos = 33,
  List<SalesInvoiceItem>? items,
  TransportDetails transport = const TransportDetails(vehicleNo: 'TN01AB1234', distanceKm: 350),
}) =>
    SalesInvoice(
      id: 1,
      invoiceNo: 'INV/26-27/0001',
      invoiceDate: DateTime(2026, 9, 20),
      buyerName: 'Sri Balaji Stores',
      buyerGstin: buyerGstin,
      buyerAddress: '45, Market Street',
      buyerPlace: 'Bengaluru',
      buyerPincode: '560001',
      placeOfSupplyStateCode: pos,
      sellerStateCode: 33,
      transport: transport,
      lastUpdated: DateTime(2026, 9, 20),
      items: items ??
          [
            SalesInvoiceItem(name: 'Steel Chair', hsnCode: '9401', quantity: 100, rate: 450, gstRate: 18),
            SalesInvoiceItem(name: 'Folding Table', hsnCode: '9403', quantity: 20, rate: 1200, gstRate: 18),
          ],
    );

void main() {
  group('round2', () {
    test('rounds half away from zero despite float error', () {
      expect(round2(1.005), 1.01);
      expect(round2(2.675), 2.68);
      expect(round2(-1.005), -1.01);
      expect(round2(10), 10);
    });
  });

  group('GSTIN', () {
    test('accepts valid GSTINs', () {
      expect(GstMaster.validateGstin('27AAPFU0939F1ZV'), isNull);
      expect(GstMaster.validateGstin(sellerGstin), isNull);
      expect(GstMaster.validateGstin(' 29aagcb7383j1z4 '), isNull, reason: 'normalises case and spaces');
    });

    test('rejects wrong check digit, length and state', () {
      expect(GstMaster.validateGstin('27AAPFU0939F1ZX'), contains('check digit'));
      expect(GstMaster.validateGstin('27AAPFU0939F1Z'), contains('15'));
      expect(GstMaster.validateGstin('99AAPFU0939F1ZV'), isNotNull);
    });

    test('state code from GSTIN', () {
      expect(GstMaster.stateCodeFromGstin(buyerGstinKa), 29);
    });
  });

  group('GstCalculator', () {
    test('intra-state exclusive rate splits CGST/SGST', () {
      final r = GstCalculator.computeLine(
        const GstLineInput(quantity: 2, rate: 500, gstRate: 18),
        interState: false,
      );
      expect(r.taxableValue, 1000);
      expect(r.cgst, 90);
      expect(r.sgst, 90);
      expect(r.igst, 0);
      expect(r.lineTotal, 1180);
    });

    test('inclusive rate back-calculates taxable value', () {
      final r = GstCalculator.computeLine(
        const GstLineInput(quantity: 1, rate: 1180, gstRate: 18, priceIncludesTax: true),
        interState: false,
      );
      expect(r.taxableValue, 1000);
      expect(r.cgst + r.sgst, 180);
    });

    test('inter-state with discount uses IGST', () {
      final r = GstCalculator.computeLine(
        const GstLineInput(quantity: 3, rate: 333.33, discountPercent: 10, gstRate: 12),
        interState: true,
      );
      expect(r.taxableValue, 899.99);
      expect(r.igst, 108);
      expect(r.cgst, 0);
    });

    test('inclusive inter-state odd amount', () {
      final r = GstCalculator.computeLine(
        const GstLineInput(quantity: 1, rate: 99.99, gstRate: 5, priceIncludesTax: true),
        interState: true,
      );
      expect(r.taxableValue, 95.23);
      expect(r.igst, 4.76);
    });

    test('invoice totals, round off and HSN summary', () {
      final t = GstCalculator.computeInvoice(const [
        GstLineInput(quantity: 2, rate: 500, gstRate: 18, hsnCode: '9401'),
        GstLineInput(quantity: 1, rate: 1180, gstRate: 18, priceIncludesTax: true, hsnCode: '9401'),
        GstLineInput(quantity: 5, rate: 49.5, gstRate: 5, hsnCode: '4819'),
      ], interState: false);
      expect(t.taxableValue, 2247.5);
      expect(t.cgst, 186.19);
      expect(t.sgst, 186.19);
      expect(t.grandTotal, 2620);
      expect(t.roundOff, 0.12);
      expect(t.hsnSummary.length, 2);
      expect(t.hsnSummary.first.taxableValue, 2000);
    });

    test('inter-state decision', () {
      expect(GstCalculator.isInterState(sellerStateCode: 33, placeOfSupplyStateCode: 29), isTrue);
      expect(GstCalculator.isInterState(sellerStateCode: 33, placeOfSupplyStateCode: 33), isFalse);
    });
  });

  group('amountInWords', () {
    test('Indian numbering', () {
      expect(amountInWords(0), 'Rupees Zero Only');
      expect(amountInWords(2620), 'Rupees Two Thousand Six Hundred Twenty Only');
      expect(amountInWords(125050.5), 'Rupees One Lakh Twenty Five Thousand Fifty and Fifty Paise Only');
      expect(amountInWords(12345678), 'Rupees One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight Only');
    });
  });

  group('Invoice numbering', () {
    test('financial year label', () {
      expect(BillingProvider.financialYear(DateTime(2026, 3, 31)), '25-26');
      expect(BillingProvider.financialYear(DateTime(2026, 4, 1)), '26-27');
    });

    test('first number in a series is 16 chars max', () {
      final no = BillingProvider().nextInvoiceNo('invoice', DateTime(2026, 9, 26));
      expect(no, 'INVOI/26-27/0001');
      expect(no.length, lessThanOrEqualTo(16));
    });
  });

  group('EwayBillJson', () {
    test('B2B inter-state bill has IGST, buyer GSTIN and consistent totals', () {
      final inv = _invoice(buyerGstin: buyerGstinKa, pos: 29);
      final file = EwayBillJson.buildFile([inv], seller);
      expect(file['version'], EwayBillJson.schemaVersion);
      final bill = (file['billLists'] as List).single as Map<String, dynamic>;
      expect(bill['supplyType'], 'O');
      expect(bill['docType'], 'INV');
      expect(bill['docDate'], '20/09/2026');
      expect(bill['toGstin'], buyerGstinKa);
      expect(bill['fromStateCode'], 33);
      expect(bill['toStateCode'], 29);
      expect(bill['totalValue'], 69000);
      expect(bill['igstValue'], 12420);
      expect(bill['cgstValue'], 0);
      expect(bill['totInvValue'], 81420);
      expect(bill['mainHsnCode'], 9401);
      expect(bill['vehicleNo'], 'TN01AB1234');
      expect(EwayBillJson.totalsConsistent(bill), isTrue);
      final item = (bill['itemList'] as List).first as Map<String, dynamic>;
      expect(item['igstRate'], 18);
      expect(item['hsnCode'], 9401);
      // Must be encodable as plain JSON.
      expect(() => jsonDecode(EwayBillJson.encode([inv], seller)), returnsNormally);
    });

    test('unregistered intra-state buyer is URP with CGST/SGST', () {
      final bill = EwayBillJson.buildBill(_invoice(pos: 33), seller);
      expect(bill['toGstin'], 'URP');
      expect(bill['cgstValue'], 6210);
      expect(bill['sgstValue'], 6210);
      final item = (bill['itemList'] as List).first as Map<String, dynamic>;
      expect(item['cgstRate'], 9);
      expect(item['sgstRate'], 9);
      expect(item['igstRate'], 0);
    });

    test('valid invoice passes validation', () {
      final v = EwayBillJson.validate(_invoice(buyerGstin: buyerGstinKa, pos: 29), seller);
      expect(v.errors, isEmpty);
    });

    test('catches common mistakes', () {
      final bad = _invoice(
        items: [SalesInvoiceItem(name: 'Consulting', hsnCode: '9983', quantity: 1, rate: 100000, gstRate: 18)],
        transport: const TransportDetails(transMode: 2, distanceKm: 5000),
      );
      const badSeller = EwbSeller(
        gstin: '33AABCT1332L1ZX',
        tradeName: '',
        address: '',
        place: '',
        pincode: '12',
        stateCode: 33,
      );
      final v = EwayBillJson.validate(bad, badSeller);
      expect(v.isValid, isFalse);
      expect(v.errors.any((e) => e.contains('GSTIN')), isTrue);
      expect(v.errors.any((e) => e.contains('services')), isTrue);
      expect(v.errors.any((e) => e.contains('4000')), isTrue);
      expect(v.errors.any((e) => e.contains('Rail/Air/Ship')), isTrue);
    });

    test('long addresses are split into two 120-char parts', () {
      final parts = EwayBillJson.splitAddress(List.filled(30, 'Street').join(', '));
      expect(parts[0].length, lessThanOrEqualTo(120));
      expect(parts[1].length, lessThanOrEqualTo(120));
      expect(parts[1], isNotEmpty);
    });
  });
}
