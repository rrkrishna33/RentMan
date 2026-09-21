import 'package:shared_preferences/shared_preferences.dart';

import 'license_service.dart';

class CopyProtectionService {
  static const String _licenseKeyKey = 'licensed_app_key';
  static const String _serverUrlKey = 'licensed_app_server_url';
  static const String _blockedKey = 'app_copy_protection_blocked';

  static String get defaultLicenseKey => '';

  static Future<String?> getSavedLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKeyKey);
  }

  static Future<void> saveLicenseKey(String licenseKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKeyKey, licenseKey.trim());
    await prefs.remove(_blockedKey);
  }

  static Future<void> saveServerUrl(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, serverUrl.trim());
  }

  static Future<String> getSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? LicenseService.defaultBaseUrl;
  }

  static Future<bool> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseKey = prefs.getString(_licenseKeyKey)?.trim() ?? '';
    final serverUrl = prefs.getString(_serverUrlKey)?.trim() ?? LicenseService.defaultBaseUrl;
    final isBlocked = prefs.getBool(_blockedKey) ?? false;

    if (isBlocked) {
      return false;
    }

    if (licenseKey.isEmpty) {
      return false;
    }

    final decision = await LicenseService.validateLicense(licenseKey, serverUrl: serverUrl);
    if (decision['allowed'] == true) {
      return true;
    }

    await prefs.setBool(_blockedKey, true);
    return false;
  }

  static Future<void> resetForDeveloperInstall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKeyKey);
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_blockedKey);
  }
}
