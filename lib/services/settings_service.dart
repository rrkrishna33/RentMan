import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages company profile, item categories and app lock preferences.
class SettingsService extends ChangeNotifier {
  static const _companyNameKey = 'company_name';
  static const _companyAddressKey = 'company_address';
  static const _companyPhoneKey = 'company_phone';
  static const _companyEmailKey = 'company_email';
  static const _companyGstNumberKey = 'company_gst_number';
  static const _companyLogoPathKey = 'company_logo_path';
  static const _categoriesKey = 'item_categories';
  static const _appLockEnabledKey = 'app_lock_enabled';
  static const _pendingOrderAlertsEnabledKey = 'pending_order_alerts_enabled';
  static const _pendingOrderAlertIntervalHoursKey = 'pending_order_alert_interval_hours';

  static const List<String> _defaultCategories = ['Furniture', 'Equipment', 'Electronics', 'Decor', 'Other'];

  String companyName = '';
  String companyAddress = '';
  String companyPhone = '';
  String companyEmail = '';
  String companyGstNumber = '';
  String? companyLogoPath;
  List<String> categories = List.of(_defaultCategories);
  bool appLockEnabled = false;
  bool pendingOrderAlertsEnabled = true;
  int pendingOrderAlertIntervalHours = 2;

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
    categories = prefs.getStringList(_categoriesKey) ?? List.of(_defaultCategories);
    appLockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
    pendingOrderAlertsEnabled = prefs.getBool(_pendingOrderAlertsEnabledKey) ?? true;
    pendingOrderAlertIntervalHours = prefs.getInt(_pendingOrderAlertIntervalHoursKey) ?? 2;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateCompanyProfile({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String gstNumber,
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
  }) async {
    pendingOrderAlertsEnabled = enabled;
    pendingOrderAlertIntervalHours = intervalHours;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingOrderAlertsEnabledKey, enabled);
    await prefs.setInt(_pendingOrderAlertIntervalHoursKey, intervalHours);
    notifyListeners();
  }
}
