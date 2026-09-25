/// Static GST master data: state codes, unit codes (UQC), GST rate slabs,
/// and GSTIN validation. Pure Dart so it can be unit tested without Flutter.
library;

class GstState {
  final int code;
  final String name;
  const GstState(this.code, this.name);

  /// Two-digit code as printed on invoices, e.g. "33".
  String get codeText => code.toString().padLeft(2, '0');

  @override
  String toString() => '$codeText - $name';
}

class GstMaster {
  GstMaster._();

  /// GST state / UT codes used on invoices and e-way bills.
  /// Code 25 (Daman & Diu) is merged into 26 since 2020; 28 is old Andhra Pradesh.
  static const List<GstState> states = [
    GstState(1, 'Jammu and Kashmir'),
    GstState(2, 'Himachal Pradesh'),
    GstState(3, 'Punjab'),
    GstState(4, 'Chandigarh'),
    GstState(5, 'Uttarakhand'),
    GstState(6, 'Haryana'),
    GstState(7, 'Delhi'),
    GstState(8, 'Rajasthan'),
    GstState(9, 'Uttar Pradesh'),
    GstState(10, 'Bihar'),
    GstState(11, 'Sikkim'),
    GstState(12, 'Arunachal Pradesh'),
    GstState(13, 'Nagaland'),
    GstState(14, 'Manipur'),
    GstState(15, 'Mizoram'),
    GstState(16, 'Tripura'),
    GstState(17, 'Meghalaya'),
    GstState(18, 'Assam'),
    GstState(19, 'West Bengal'),
    GstState(20, 'Jharkhand'),
    GstState(21, 'Odisha'),
    GstState(22, 'Chhattisgarh'),
    GstState(23, 'Madhya Pradesh'),
    GstState(24, 'Gujarat'),
    GstState(26, 'Dadra and Nagar Haveli and Daman and Diu'),
    GstState(27, 'Maharashtra'),
    GstState(29, 'Karnataka'),
    GstState(30, 'Goa'),
    GstState(31, 'Lakshadweep'),
    GstState(32, 'Kerala'),
    GstState(33, 'Tamil Nadu'),
    GstState(34, 'Puducherry'),
    GstState(35, 'Andaman and Nicobar Islands'),
    GstState(36, 'Telangana'),
    GstState(37, 'Andhra Pradesh'),
    GstState(38, 'Ladakh'),
    GstState(97, 'Other Territory'),
  ];

  static GstState? stateByCode(int? code) {
    if (code == null) return null;
    for (final s in states) {
      if (s.code == code) return s;
    }
    return null;
  }

  static String stateLabel(int? code) => stateByCode(code)?.toString() ?? '-';

  /// Unit Quantity Codes accepted by the e-way bill system.
  static const Map<String, String> units = {
    'NOS': 'Numbers',
    'PCS': 'Pieces',
    'UNT': 'Units',
    'SET': 'Sets',
    'PRS': 'Pairs',
    'DOZ': 'Dozens',
    'BOX': 'Box',
    'PAC': 'Packs',
    'BAG': 'Bags',
    'BTL': 'Bottles',
    'KGS': 'Kilograms',
    'GMS': 'Grams',
    'QTL': 'Quintal',
    'TON': 'Tonnes',
    'LTR': 'Litre',
    'MLT': 'Millilitre',
    'MTR': 'Metres',
    'SQF': 'Square Feet',
    'SQM': 'Square Metres',
    'OTH': 'Others',
  };

  /// GST rate slabs offered in the item/product pickers.
  static const List<double> gstRates = [0, 0.25, 3, 5, 12, 18, 28, 40];

  static const _gstinChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static final RegExp _gstinPattern =
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  /// Normalises user input: trims, removes spaces, upper-cases.
  static String normalizeGstin(String input) => input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Returns null when [gstin] is a structurally valid GSTIN with a correct
  /// check digit and a known state code, otherwise a human readable error.
  static String? validateGstin(String gstin) {
    final g = normalizeGstin(gstin);
    if (g.length != 15) return 'GSTIN must be 15 characters';
    if (!_gstinPattern.hasMatch(g)) return 'GSTIN format is invalid';
    final state = int.tryParse(g.substring(0, 2));
    if (stateByCode(state) == null) return 'GSTIN has an unknown state code';
    if (gstinCheckChar(g.substring(0, 14)) != g[14]) return 'GSTIN check digit does not match';
    return null;
  }

  static bool isValidGstin(String gstin) => validateGstin(gstin) == null;

  /// State code from the first two digits of a GSTIN, or null.
  static int? stateCodeFromGstin(String gstin) {
    final g = normalizeGstin(gstin);
    if (g.length < 2) return null;
    return int.tryParse(g.substring(0, 2));
  }

  /// Computes the 15th (checksum) character of a GSTIN from its first 14.
  static String gstinCheckChar(String first14) {
    var sum = 0;
    for (var i = 0; i < 14; i++) {
      final value = _gstinChars.indexOf(first14[i]);
      final factor = i.isEven ? 1 : 2;
      final product = value * factor;
      sum += (product ~/ 36) + (product % 36);
    }
    final check = (36 - (sum % 36)) % 36;
    return _gstinChars[check];
  }
}
