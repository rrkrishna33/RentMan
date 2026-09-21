import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/booking_provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _companyFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _gstController;
  final _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _nameController = TextEditingController(text: settings.companyName);
    _addressController = TextEditingController(text: settings.companyAddress);
    _phoneController = TextEditingController(text: settings.companyPhone);
    _emailController = TextEditingController(text: settings.companyEmail);
    _gstController = TextEditingController(text: settings.companyGstNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _updatePendingOrderAlertSettings({
    required bool enabled,
    required int intervalHours,
    required int startDaysBefore,
  }) async {
    final settings = context.read<SettingsService>();
    await settings.updatePendingOrderAlertSettings(
      enabled: enabled,
      intervalHours: intervalHours,
      startDaysBefore: startDaysBefore,
    );
    if (!mounted) return;
    await context.read<BookingProvider>().syncAllPendingOrderAlerts(settings);
  }

  Future<void> _saveCompanyProfile() async {
    await context.read<SettingsService>().updateCompanyProfile(
          name: _nameController.text,
          address: _addressController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          gstNumber: _gstController.text,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Company profile saved')),
    );
  }

  void _addCategory() {
    final value = _categoryController.text.trim();
    if (value.isEmpty) return;
    context.read<SettingsService>().addCategory(value);
    _categoryController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickCompanyLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final suffix = DateTime.now().millisecondsSinceEpoch;
    final logoPath = '${directory.path}/company_logo_$suffix${_extensionFor(picked.path)}';

    final file = File(picked.path);
    if (await file.exists()) {
      await file.copy(logoPath);
    }

    if (!mounted) return;
    await context.read<SettingsService>().updateCompanyLogo(logoPath);
  }

  String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '.jpg' : path.substring(dot);
  }

  Future<void> _removeCompanyLogo() async {
    final settings = context.read<SettingsService>();
    final path = settings.companyLogoPath;
    await settings.updateCompanyLogo(null);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          GradientHeader(
            height: 120,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<SettingsService>(
              builder: (context, settings, _) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionCard(
                      title: 'Company Profile',
                      subtitle: 'Shown on generated bills/invoices',
                      child: Form(
                        key: _companyFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                hintText: 'Company / Shop name',
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'Address',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'Phone number',
                                prefixIcon: Icon(Icons.call_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _gstController,
                              decoration: const InputDecoration(
                                hintText: 'GST Number',
                                prefixIcon: Icon(Icons.receipt_long_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: settings.companyLogoPath != null && File(settings.companyLogoPath!).existsSync()
                                      ? Image.file(File(settings.companyLogoPath!), fit: BoxFit.contain)
                                      : const Icon(Icons.image_outlined, color: Colors.grey, size: 30),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Company Logo', style: TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Text('Shown at the top of generated invoices', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      const SizedBox(height: 7),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _pickCompanyLogo,
                                            icon: const Icon(Icons.upload_outlined, size: 17),
                                            label: Text(settings.companyLogoPath == null ? 'Choose Logo' : 'Change Logo'),
                                          ),
                                          if (settings.companyLogoPath != null)
                                            TextButton(
                                              onPressed: _removeCompanyLogo,
                                              child: const Text('Remove'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveCompanyProfile,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save Company Profile'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Item Categories',
                      subtitle: 'Manage categories used when adding booking items',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (settings.categories.isEmpty)
                            Text('No categories yet', style: TextStyle(color: Colors.grey[500]))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: settings.categories.map((category) {
                                return Chip(
                                  label: Text(category),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => context.read<SettingsService>().deleteCategory(category),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _categoryController,
                                  decoration: const InputDecoration(
                                    hintText: 'New category name',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  onSubmitted: (_) => _addCategory(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _addCategory,
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Pending Order Alerts',
                      subtitle: 'Repeating alert until an order is dispatched',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable Alerts'),
                            subtitle: const Text('Keep notifying until the order is marked dispatched'),
                            value: settings.pendingOrderAlertsEnabled,
                            activeColor: AppTheme.primary,
                            onChanged: (value) => _updatePendingOrderAlertSettings(
                              enabled: value,
                              intervalHours: settings.pendingOrderAlertIntervalHours,
                              startDaysBefore: settings.pendingOrderAlertStartDaysBefore,
                            ),
                          ),
                          if (settings.pendingOrderAlertsEnabled) ...[
                            const SizedBox(height: 8),
                            const Text('Start alerting', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [0, 1, 2, 3, 5, 7].map((days) {
                                final selected = settings.pendingOrderAlertStartDaysBefore == days;
                                return ChoiceChip(
                                  label: Text(days == 0 ? 'At booking' : '$days day${days > 1 ? 's' : ''} before'),
                                  selected: selected,
                                  onSelected: (_) => _updatePendingOrderAlertSettings(
                                    enabled: settings.pendingOrderAlertsEnabled,
                                    intervalHours: settings.pendingOrderAlertIntervalHours,
                                    startDaysBefore: days,
                                  ),
                                  selectedColor: AppTheme.primary,
                                  labelStyle: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  backgroundColor: Colors.white,
                                  side: BorderSide.none,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            const Text('Repeat every', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [1, 2].map((hours) {
                                final selected = settings.pendingOrderAlertIntervalHours == hours;
                                return ChoiceChip(
                                  label: Text('$hours hour${hours > 1 ? 's' : ''}'),
                                  selected: selected,
                                  onSelected: (_) => _updatePendingOrderAlertSettings(
                                    enabled: settings.pendingOrderAlertsEnabled,
                                    intervalHours: hours,
                                    startDaysBefore: settings.pendingOrderAlertStartDaysBefore,
                                  ),
                                  selectedColor: AppTheme.primary,
                                  labelStyle: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  backgroundColor: Colors.white,
                                  side: BorderSide.none,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Note: changes only apply to bookings still pending dispatch, and to those becoming due for their first alert. Once started, a booking keeps repeating until dispatched.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Security',
                      subtitle: 'Require your phone lock or biometrics to open the app',
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('App Lock'),
                        subtitle: const Text('Unlock with fingerprint, face or device PIN'),
                        value: settings.appLockEnabled,
                        activeColor: AppTheme.primary,
                        onChanged: (value) async {
                          if (value) {
                            final localAuth = LocalAuthentication();
                            bool supported = false;
                            try {
                              supported = await localAuth.isDeviceSupported() || await localAuth.canCheckBiometrics;
                            } catch (_) {
                              supported = false;
                            }
                            if (!supported) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Set up a screen lock or fingerprint on your phone first, then enable App Lock here.",
                                  ),
                                ),
                              );
                              return;
                            }
                          }
                          if (!context.mounted) return;
                          await context.read<SettingsService>().setAppLockEnabled(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'About',
                      subtitle: 'App information and credits',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('RentMan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                Text('A comprehensive rental management solution', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                const SizedBox(height: 12),
                                const Divider(height: 0),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.code_outlined, size: 18, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text('Built by GellSoft', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.info_outlined, size: 18, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    const Text('Version 1.0.0', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'GellSoft - Premium Software Solutions',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
