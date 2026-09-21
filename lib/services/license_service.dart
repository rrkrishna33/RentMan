import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class LicenseService {
  static const String defaultBaseUrl = 'https://license.gellsoft.com';

  static String baseUrl = defaultBaseUrl;

  static Future<Map<String, dynamic>> validateLicense(String licenseKey, {String serverUrl = defaultBaseUrl}) async {
    final normalizedUrl = serverUrl.trim();
    final cleanUrl = normalizedUrl.replaceAll(RegExp(r'/+$'), '');
    final machineId = await _machineId();
    final appVersion = await _appVersion();

    try {
      final response = await http.post(
        Uri.parse('$cleanUrl/api/licenses/activate-validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'licenseKey': licenseKey.trim(),
          'machineId': machineId,
          'appVersion': appVersion,
        }),
      );

      if (response.statusCode != 200) {
        final body = response.body;
        return {
          'ok': false,
          'allowed': false,
          'reason': body.isNotEmpty ? body : 'License validation failed (${response.statusCode})',
        };
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {'ok': false, 'allowed': false, 'reason': 'Unexpected license server response'};
    } catch (_) {
      return {
        'ok': false,
        'allowed': false,
        'reason': 'Unable to reach the license server. Check the server URL and network connection.',
      };
    }
  }

  static Future<String> _machineId() async {
    final info = await DeviceInfoPlugin().androidInfo;
    final deviceId = info.id;
    return deviceId.isEmpty ? 'unknown-device' : deviceId;
  }

  static Future<String> _appVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
