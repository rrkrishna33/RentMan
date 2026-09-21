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
  static const _remindersEnabledKey = 'reminders_enabled';
  static const _reminderDaysBeforeKey = 'reminder_days_before';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';

  static const List<String> _defaultCategories = ['Furniture', 'Equipment', 'Electronics', 'Decor', 'Other'];

  String companyName = '';
  String companyAddress = '';
  String companyPhone = '';
  String companyEmail = '';
  String companyGstNumber = '';
  String? companyLogoPath;
  List<String> categories = List.of(_defaultCategories);
  bool appLockEnabled = false;
  bool remindersEnabled = true;
  int reminderDaysBefore = 5;
  int reminderHour = 9;
  int reminderMinute = 0;

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
    remindersEnabled = prefs.getBool(_remindersEnabledKey) ?? true;
    reminderDaysBefore = prefs.getInt(_reminderDaysBeforeKey) ?? 5;
    reminderHour = prefs.getInt(_reminderHourKey) ?? 9;
    reminderMinute = prefs.getInt(_reminderMinuteKey) ?? 0;
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

  Future<void> updateReminderSettings({
    required bool enabled,
    required int daysBefore,
    required int hour,
    required int minute,
  }) async {
    remindersEnabled = enabled;
    reminderDaysBefore = daysBefore;
    reminderHour = hour;
    reminderMinute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersEnabledKey, enabled);
    await prefs.setInt(_reminderDaysBeforeKey, daysBefore);
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
    notifyListeners();
  }
}
