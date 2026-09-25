import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import '../services/booking_provider.dart';
import '../models/customer.dart';
import '../gst/gst_master.dart';
import '../theme/app_theme.dart';
import 'billing/billing_widgets.dart' show GstStateDropdown;

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  bool get isEditing => customer != null;

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.customer?.name);
  late final _phoneController = TextEditingController(text: widget.customer?.phone);
  late final _addressController = TextEditingController(text: widget.customer?.address);
  late final _gstinController = TextEditingController(text: widget.customer?.gstin);
  late final _cityController = TextEditingController(text: widget.customer?.city);
  late final _pincodeController = TextEditingController(text: widget.customer?.pincode);
  late int? _stateCode = widget.customer?.stateCode;
  bool _isPickingContact = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<BookingProvider>();
      String? orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      final gstin = orNull(_gstinController) == null ? null : GstMaster.normalizeGstin(_gstinController.text);
      if (widget.isEditing) {
        await provider.updateCustomer(
          id: widget.customer!.id!,
          name: _nameController.text,
          phone: _phoneController.text,
          address: _addressController.text.isEmpty ? null : _addressController.text,
          createdDate: widget.customer!.createdDate,
          gstin: gstin,
          stateCode: _stateCode,
          city: orNull(_cityController),
          pincode: orNull(_pincodeController),
        );
      } else {
        await provider.addCustomer(
          _nameController.text,
          _phoneController.text,
          _addressController.text.isEmpty ? null : _addressController.text,
          gstin: gstin,
          stateCode: _stateCode,
          city: orNull(_cityController),
          pincode: orNull(_pincodeController),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEditing ? 'Customer updated successfully!' : 'Customer added successfully!')),
      );
    }
  }

  Future<void> _pickFromContacts() async {
    if (_isPickingContact) return;
    setState(() => _isPickingContact = true);
    try {
      final allowed = await FlutterContacts.requestPermission(readonly: true);
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission is required to pick a customer.')),
        );
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      if (!mounted) return;

      final usableContacts = contacts.where((c) => c.displayName.trim().isNotEmpty).toList();
      if (usableContacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts found on this phone.')),
        );
        return;
      }

      final selected = await showModalBottomSheet<Contact>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _ContactPickerSheet(contacts: usableContacts),
      );
      if (selected == null) return;

      _nameController.text = selected.displayName.trim();
      if (selected.phones.isNotEmpty) {
        _phoneController.text = selected.phones.first.number.trim();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read contacts right now. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingContact = false);
      }
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
                Text(
                  widget.isEditing ? 'Edit Customer' : 'Add Customer',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Full Name', required: true),
                    const SizedBox(height: 8),
                    if (!widget.isEditing)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _isPickingContact ? null : _pickFromContacts,
                          icon: _isPickingContact
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.contacts_outlined, size: 18),
                          label: Text(_isPickingContact ? 'Loading Contacts...' : 'Pick from Contacts'),
                        ),
                      ),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Priya Sharma',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter customer name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    const _FieldLabel('Phone Number', required: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 98765 43210',
                        prefixIcon: Icon(Icons.call_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    const _FieldLabel('Address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Address (optional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text('GST Details (for tax invoices)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const _FieldLabel('GSTIN'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _gstinController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Leave empty if unregistered',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                      onChanged: (value) {
                        final state = GstMaster.stateCodeFromGstin(value);
                        if (value.trim().length >= 2 && GstMaster.stateByCode(state) != null && state != _stateCode) {
                          setState(() => _stateCode = state);
                        }
                      },
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return null;
                        return GstMaster.validateGstin(value!);
                      },
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('State'),
                    const SizedBox(height: 8),
                    GstStateDropdown(value: _stateCode, onChanged: (v) => setState(() => _stateCode = v)),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(hintText: 'City / Place'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(hintText: 'PIN code', counterText: ''),
                            validator: (value) {
                              final v = (value ?? '').trim();
                              if (v.isEmpty) return null;
                              return RegExp(r'^[1-9][0-9]{5}$').hasMatch(v) ? null : '6 digits';
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(widget.isEditing ? 'Save Changes' : 'Add Customer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;

  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  late TextEditingController _searchController;
  List<Contact> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredContacts = widget.contacts;
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = widget.contacts
          .where((contact) =>
              contact.displayName.toLowerCase().contains(query) ||
              (contact.phones.isNotEmpty &&
                  contact.phones.first.number.toLowerCase().contains(query)))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = _filteredContacts.where((contact) => contact.displayName.trim().isNotEmpty).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose a Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search_outlined, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_outlined, size: 20),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: available.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'No contacts with names found'
                            : 'No contacts matching your search',
                      ),
                    )
                  : ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final contact = available[index];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(contact.displayName),
                          subtitle: Text(contact.phones.isEmpty ? 'No phone number' : contact.phones.first.number),
                          onTap: () => Navigator.pop(context, contact),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _FieldLabel(this.label, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
        children: required
            ? const [TextSpan(text: ' *', style: TextStyle(color: AppTheme.danger))]
            : null,
      ),
    );
  }
}
