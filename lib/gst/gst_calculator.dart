/// GST computation for sales invoices. Pure Dart (no Flutter) so it can be
/// unit tested with `flutter test test/gst_calculator_test.dart`.
///
/// Rules implemented:
/// * Intra-state supply (seller state == place of supply) -> CGST + SGST,
///   each at half the GST rate.
/// * Inter-state supply -> IGST at the full rate.
/// * Rates may be entered inclusive of tax; the taxable value is then
///   back-calculated as amount * 100 / (100 + rate).
/// * Every tax amount is rounded to paise per line; the invoice total is
///   rounded to the nearest rupee and the difference shown as "Round off".
library;

/// Rounds to 2 decimals, half away from zero, tolerant of binary float error
/// (so 1.005 -> 1.01, not 1.00).
double round2(double value) {
  // Dart's roundToDouble() rounds half away from zero; the epsilon nudges
  // values like 100.49999999999999 (from 1.005 * 100) up to the intended half.
  final rounded = (value.abs() * 100 + 1e-7).roundToDouble() / 100;
  return value < 0 ? -rounded : rounded;
}

/// The inputs the calculator needs for one invoice line.
class GstLineInput {
  final double quantity;
  final double rate;
  final double discountPercent;
  final double gstRate;
  final bool priceIncludesTax;
  final String hsnCode;

  const GstLineInput({
    required this.quantity,
    required this.rate,
    this.discountPercent = 0,
    required this.gstRate,
    this.priceIncludesTax = false,
    this.hsnCode = '',
  });
}

class GstLineResult {
  final double grossAmount; // qty * rate, after discount, as entered
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;

  const GstLineResult({
    required this.grossAmount,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
  });

  double get totalTax => round2(cgst + sgst + igst);
  double get lineTotal => round2(taxableValue + totalTax);
}

/// Per-HSN, per-rate aggregate printed in the HSN summary on the invoice.
class HsnSummaryRow {
  final String hsnCode;
  final double gstRate;
  double taxableValue = 0;
  double cgst = 0;
  double sgst = 0;
  double igst = 0;

  HsnSummaryRow(this.hsnCode, this.gstRate);

  double get totalTax => round2(cgst + sgst + igst);
}

class GstInvoiceTotals {
  final List<GstLineResult> lines;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double roundOff;
  final double grandTotal;
  final bool interState;
  final List<HsnSummaryRow> hsnSummary;

  const GstInvoiceTotals({
    required this.lines,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.roundOff,
    required this.grandTotal,
    required this.interState,
    required this.hsnSummary,
  });

  double get totalTax => round2(cgst + sgst + igst);
}

class GstCalculator {
  GstCalculator._();

  static bool isInterState({required int? sellerStateCode, required int? placeOfSupplyStateCode}) {
    if (sellerStateCode == null || placeOfSupplyStateCode == null) return false;
    return sellerStateCode != placeOfSupplyStateCode;
  }

  static GstLineResult computeLine(GstLineInput line, {required bool interState}) {
    final discount = line.discountPercent.clamp(0, 100) / 100;
    final gross = round2(line.quantity * line.rate * (1 - discount));
    final taxable = line.priceIncludesTax
        ? round2(gross * 100 / (100 + line.gstRate))
        : gross;

    if (interState) {
      return GstLineResult(
        grossAmount: gross,
        taxableValue: taxable,
        cgst: 0,
        sgst: 0,
        igst: round2(taxable * line.gstRate / 100),
      );
    }
    final half = round2(taxable * line.gstRate / 200);
    return GstLineResult(grossAmount: gross, taxableValue: taxable, cgst: half, sgst: half, igst: 0);
  }

  static GstInvoiceTotals computeInvoice(List<GstLineInput> lines, {required bool interState}) {
    final results = <GstLineResult>[];
    final hsn = <String, HsnSummaryRow>{};
    var taxable = 0.0, cgst = 0.0, sgst = 0.0, igst = 0.0;

    for (final line in lines) {
      final r = computeLine(line, interState: interState);
      results.add(r);
      taxable += r.taxableValue;
      cgst += r.cgst;
      sgst += r.sgst;
      igst += r.igst;

      final key = '${line.hsnCode}|${line.gstRate}';
      final row = hsn.putIfAbsent(key, () => HsnSummaryRow(line.hsnCode, line.gstRate));
      row.taxableValue = round2(row.taxableValue + r.taxableValue);
      row.cgst = round2(row.cgst + r.cgst);
      row.sgst = round2(row.sgst + r.sgst);
      row.igst = round2(row.igst + r.igst);
    }

    taxable = round2(taxable);
    cgst = round2(cgst);
    sgst = round2(sgst);
    igst = round2(igst);
    final beforeRound = round2(taxable + cgst + sgst + igst);
    final grand = beforeRound.roundToDouble();

    return GstInvoiceTotals(
      lines: results,
      taxableValue: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      roundOff: round2(grand - beforeRound),
      grandTotal: grand,
      interState: interState,
      hsnSummary: hsn.values.toList(),
    );
  }

  /// Formats a rate for display: 18 -> "18", 0.25 -> "0.25".
  static String formatRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();
}
