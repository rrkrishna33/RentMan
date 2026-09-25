import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/sales_invoice.dart';

/// State + persistence for the GST billing module (products and sales invoices).
class BillingProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Product> _products = [];
  List<SalesInvoice> _invoices = [];
  bool _loaded = false;

  List<Product> get products => _products;
  List<SalesInvoice> get invoices => _invoices;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _products = await _db.getAllProducts();
    _invoices = await _db.getAllSalesInvoices();
    _loaded = true;
    notifyListeners();
  }

  // ==================== PRODUCTS ====================

  /// Inserts or updates a product and returns the stored copy (with id).
  Future<Product> saveProduct(Product product) async {
    var saved = product;
    if (product.id == null) {
      final id = await _db.insertProduct(product);
      saved = product.copyWith(id: id);
      _products.add(saved);
    } else {
      await _db.updateProduct(product);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) _products[index] = product;
    }
    _products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return saved;
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ==================== INVOICES ====================

  SalesInvoice? getInvoice(int? id) {
    if (id == null) return null;
    for (final inv in _invoices) {
      if (inv.id == id) return inv;
    }
    return null;
  }

  /// Indian financial year label for a date, e.g. 2026-09-26 -> "26-27".
  static String financialYear(DateTime date) {
    final start = date.month >= 4 ? date.year : date.year - 1;
    final a = (start % 100).toString().padLeft(2, '0');
    final b = ((start + 1) % 100).toString().padLeft(2, '0');
    return '$a-$b';
  }

  /// Next invoice number in the series PREFIX/YY-YY/0001, restarting each
  /// financial year. GST requires numbers to be unique per FY and at most
  /// 16 characters, so the prefix is trimmed to fit.
  String nextInvoiceNo(String prefix, DateTime date) {
    final fy = financialYear(date);
    var cleanPrefix = prefix.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '').toUpperCase();
    if (cleanPrefix.isEmpty) cleanPrefix = 'INV';
    if (cleanPrefix.length > 5) cleanPrefix = cleanPrefix.substring(0, 5);
    final series = '$cleanPrefix/$fy/';
    var maxSeq = 0;
    for (final inv in _invoices) {
      if (inv.invoiceNo.startsWith(series)) {
        final seq = int.tryParse(inv.invoiceNo.substring(series.length)) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    return '$series${(maxSeq + 1).toString().padLeft(4, '0')}';
  }

  Future<bool> invoiceNoTaken(String invoiceNo, {int? excludingId}) =>
      _db.invoiceNoExists(invoiceNo, excludingId: excludingId);

  /// Creates or updates an invoice with its items. Returns the saved invoice.
  Future<SalesInvoice> saveInvoice(SalesInvoice invoice) async {
    final id = await _db.saveSalesInvoice(invoice);
    final saved = invoice.copyWith(id: id);
    final index = _invoices.indexWhere((i) => i.id == id);
    if (index == -1) {
      _invoices.insert(0, saved);
    } else {
      _invoices[index] = saved;
    }
    _sortInvoices();
    notifyListeners();
    return saved;
  }

  /// Saves header-only changes (payment, transport, e-way bill number).
  Future<SalesInvoice> updateInvoiceHeader(SalesInvoice invoice) async {
    final updated = invoice.copyWith(lastUpdated: DateTime.now());
    await _db.updateSalesInvoiceHeader(updated);
    final index = _invoices.indexWhere((i) => i.id == invoice.id);
    if (index != -1) _invoices[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<void> deleteInvoice(int id) async {
    await _db.deleteSalesInvoice(id);
    _invoices.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void _sortInvoices() {
    _invoices.sort((a, b) {
      final byDate = b.invoiceDate.compareTo(a.invoiceDate);
      return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }

  /// Sales and tax totals for the given month (for the billing dashboard).
  ({double sales, double tax, int count}) monthSummary(DateTime month) {
    var sales = 0.0, tax = 0.0, count = 0;
    for (final inv in _invoices) {
      if (inv.invoiceDate.year == month.year && inv.invoiceDate.month == month.month) {
        final t = inv.totals;
        sales += t.grandTotal;
        tax += t.totalTax;
        count++;
      }
    }
    return (sales: sales, tax: tax, count: count);
  }
}
