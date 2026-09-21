import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/copy_protection_service.dart';
import '../services/license_service.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final _licenseKeyController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  Future<void> _loadSavedValues() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('licensed_app_key') ?? '';
    final savedUrl = prefs.getString('licensed_app_server_url') ?? LicenseService.defaultBaseUrl;

    if (!mounted) return;

    setState(() {
      _licenseKeyController.text = savedKey;
      _serverUrlController.text = savedUrl;
    });
  }

  Future<void> _activate() async {
    final licenseKey = _licenseKeyController.text.trim();
    final serverUrl = _serverUrlController.text.trim();
    final navigator = Navigator.of(context);

    if (licenseKey.isEmpty) {
      setState(() => _error = 'Enter your license key to continue.');
      return;
    }

    if (serverUrl.isEmpty) {
      setState(() => _error = 'Enter the license server URL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final decision = await LicenseService.validateLicense(licenseKey, serverUrl: serverUrl);

    if (!mounted) return;

    if (decision['allowed'] == true) {
      await CopyProtectionService.saveLicenseKey(licenseKey);
      await CopyProtectionService.saveServerUrl(serverUrl);
      await SharedPreferences.getInstance().then((prefs) => prefs.remove('app_copy_protection_blocked'));
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const RentManApp()),
      );
      return;
    }

    setState(() {
      _isLoading = false;
      _error = decision['reason'] ?? 'This license is not valid for this device.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RentMan - by GellSoft',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'License Activation',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter your license key and the server URL supplied by the vendor.',
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _licenseKeyController,
                          decoration: const InputDecoration(
                            labelText: 'License Key',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _serverUrlController,
                          decoration: const InputDecoration(
                            labelText: 'License Server URL',
                            hintText: 'https://license.gellsoft.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _activate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Activate License', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
}
