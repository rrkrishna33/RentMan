import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gst/eway_bill_json.dart';

/// Manages company profile, item categories and app lock preferences.
class SettingsService extends ChangeNotifier {
  static const _companyNameKey = 'company_name';
  static const _companyAddressKey = 'company_address';
  static const _companyPhoneKey = 'company_phone';
  static const _companyEmailKey = 'company_email';
  static const _companyGstNumberKey = 'company_gst_number';
  static const _companyLogoPathKey = 'company_logo_path';
  static const _companyStateCodeKey = 'company_state_code';
  static const _companyCityKey = 'company_city';
  static const _companyPincodeKey = 'company_pincode';
  static const _invoicePrefixKey = 'invoice_prefix';
  static const _categoriesKey = 'item_categories';
  static const _appLockEnabledKey = 'app_lock_enabled';
  static const _pendingOrderAlertsEnabledKey = 'pending_order_alerts_enabled';
  static const _pendingOrderAlertIntervalHoursKey = 'pending_order_alert_interval_hours';
  static const _pendingOrderAlertStartDaysBeforeKey = 'pending_order_alert_start_days_before';

  static const List<String> _defaultCategories = ['Furniture', 'Equipment', 'Electronics', 'Decor', 'Other'];

  String companyName = '';
  String companyAddress = '';
  String companyPhone = '';
  String companyEmail = '';
  String companyGstNumber = '';
  String? companyLogoPath;
  // GST billing profile
  int? companyStateCode;
  String companyCity = '';
  String companyPincode = '';
  String invoicePrefix = 'INV';
  List<String> categories = List.of(_defaultCategories);
  bool appLockEnabled = false;
  bool pendingOrderAlertsEnabled = true;
  int pendingOrderAlertIntervalHours = 2;
  // How many days before the rental date the repeating alert starts firing.
  // 0 means it starts as soon as the booking is created.
  int pendingOrderAlertStartDaysBefore = 2;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    companyName = prefs.getString(_companyNameKey) ?? '';
    companyAddress = prefs.getString(_companyAddressKey) ?? '';
    companyPhone = prefs.getString(_companyPhoneKey) ?? '';
    companyEmail = prefs.getString(_companyEmailKey) ?? '';
    companyGstNumber = prefs.getString(_companyGstNumberKey) ?? '';
    companyLogoPath = prefs.getString(_companyLogoPathKey);
    companyStateCode = prefs.getInt(_companyStateCodeKey);
    companyCity = prefs.getString(_companyCityKey) ?? '';
    companyPincode = prefs.getString(_companyPincodeKey) ?? '';
    invoicePrefix = prefs.getString(_invoicePrefixKey) ?? 'INV';
    categories = prefs.getStringList(_categoriesKey) ?? List.of(_defaultCategories);
    appLockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
    pendingOrderAlertsEnabled = prefs.getBool(_pendingOrderAlertsEnabledKey) ?? true;
    pendingOrderAlertIntervalHours = prefs.getInt(_pendingOrderAlertIntervalHoursKey) ?? 2;
    pendingOrderAlertStartDaysBefore = prefs.getInt(_pendingOrderAlertStartDaysBeforeKey) ?? 2;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateCompanyProfile({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String gstNumber,
    int? stateCode,
    String city = '',
    String pincode = '',
    String? invoicePrefix,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    companyName = name;
    companyAddress = address;
    companyPhone = phone;
    companyEmail = email;
    companyGstNumber = gstNumber;
    await prefs.setString(_companyNameKey, name);
    await prefs.setString(_companyAddressKey, address);
    await prefs.setString(_companyPhoneKey, phone);
    await prefs.setString(_companyEmailKey, email);
    await prefs.setString(_companyGstNumberKey, gstNumber);
    companyStateCode = stateCode;
    companyCity = city;
    companyPincode = pincode;
    if (stateCode == null) {
      await prefs.remove(_companyStateCodeKey);
    } else {
      await prefs.setInt(_companyStateCodeKey, stateCode);
    }
    await prefs.setString(_companyCityKey, city);
    await prefs.setString(_companyPincodeKey, pincode);
    if (invoicePrefix != null && invoicePrefix.trim().isNotEmpty) {
      this.invoicePrefix = invoicePrefix.trim().toUpperCase();
      await prefs.setString(_invoicePrefixKey, this.invoicePrefix);
    }
    notifyListeners();
  }

  Future<void> updateCompanyLogo(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    companyLogoPath = path;
    if (path == null || path.isEmpty) {
      await prefs.remove(_companyLogoPathKey);
    } else {
      await prefs.setString(_companyLogoPathKey, path);
    }
    notifyListeners();
  }

  Future<void> addCategory(String category) async {
    final normalized = category.trim();
    if (normalized.isEmpty || categories.any((c) => c.toLowerCase() == normalized.toLowerCase())) {
      return;
    }
    categories = [...categories, normalized];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoriesKey, categories);
    notifyListeners();
  }

  Future<void> deleteCategory(String category) async {
    categories = categories.where((c) => c != category).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoriesKey, categories);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    appLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> updatePendingOrderAlertSettings({
    required bool enabled,
    required int intervalHours,
    required int startDaysBefore,
  }) async {
    pendingOrderAlertsEnabled = enabled;
    pendingOrderAlertIntervalHours = intervalHours;
    pendingOrderAlertStartDaysBefore = startDaysBefore;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingOrderAlertsEnabledKey, enabled);
    await prefs.setInt(_pendingOrderAlertIntervalHoursKey, intervalHours);
    await prefs.setInt(_pendingOrderAlertStartDaysBeforeKey, startDaysBefore);
    notifyListeners();
  }

  /// Seller details used for e-way bill JSON.
  EwbSeller get ewbSeller => EwbSeller(
        gstin: companyGstNumber,
        tradeName: companyName,
        address: companyAddress,
        place: companyCity,
        pincode: companyPincode,
        stateCode: companyStateCode ?? 0,
      );

  /// True when enough of the company profile is filled in to issue GST invoices.
  bool get gstProfileComplete => companyName.isNotEmpty && companyStateCode != null;
}
