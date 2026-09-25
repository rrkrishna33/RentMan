/// Converts a rupee amount to Indian-system words for tax invoices, e.g.
/// 125050.50 -> "Rupees One Lakh Twenty Five Thousand Fifty and Fifty Paise Only".
library;

const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen',
  'Eighteen', 'Nineteen',
];
const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

String _twoDigits(int n) {
  if (n < 20) return _ones[n];
  final t = _tens[n ~/ 10];
  final o = _ones[n % 10];
  return o.isEmpty ? t : '$t $o';
}

String _threeDigits(int n) {
  final hundred = n ~/ 100;
  final rest = n % 100;
  final parts = <String>[];
  if (hundred > 0) parts.add('${_ones[hundred]} Hundred');
  if (rest > 0) parts.add(_twoDigits(rest));
  return parts.join(' ');
}

/// Whole number to words using crore / lakh / thousand grouping.
String numberToIndianWords(int number) {
  if (number == 0) return 'Zero';
  if (number < 0) return 'Minus ${numberToIndianWords(-number)}';

  final parts = <String>[];
  final crore = number ~/ 10000000;
  number %= 10000000;
  final lakh = number ~/ 100000;
  number %= 100000;
  final thousand = number ~/ 1000;
  number %= 1000;

  if (crore > 0) parts.add('${numberToIndianWords(crore)} Crore');
  if (lakh > 0) parts.add('${_twoDigits(lakh)} Lakh');
  if (thousand > 0) parts.add('${_twoDigits(thousand)} Thousand');
  if (number > 0) parts.add(_threeDigits(number));
  return parts.join(' ');
}

String amountInWords(double amount) {
  final totalPaise = (amount.abs() * 100 + 1e-7).round();
  final rupees = totalPaise ~/ 100;
  final paise = totalPaise % 100;
  final buffer = StringBuffer('Rupees ${numberToIndianWords(rupees)}');
  if (paise > 0) buffer.write(' and ${_twoDigits(paise)} Paise');
  buffer.write(' Only');
  return buffer.toString();
}
