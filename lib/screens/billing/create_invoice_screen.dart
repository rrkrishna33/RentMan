import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gst/gst_calculator.dart';
import '../../gst/gst_master.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/sales_invoice.dart';
import '../../services/billing_provider.dart';
import '../../services/booking_provider.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../settings_screen.dart';
import 'billing_widgets.dart';
import 'invoice_details_screen.dart';
import 'products_screen.dart';

/// Create a new GST tax invoice, or edit an existing one.
class CreateInvoiceScreen extends StatefulWidget {
  final SalesInvoice? invoice;

  const CreateInvoiceScreen({super.key, this.invoice});

  bool get isEditing => invoice != null;

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _invoiceNo;
  late final TextEditingController _buyerName;
  late final TextEditingController _buyerGstin;
  late final TextEditingController _buyerPhone;
  late final TextEditingController _buyerAddress;
  late final TextEditingController _buyerPlace;
  late final TextEditingController _buyerPincode;
  late final TextEditingController _paid;
  late final TextEditingController _notes;

  late DateTime _invoiceDate;
  int? _customerId;
  int? _placeOfSupply;
  late List<SalesInvoiceItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    final settings = context.read<SettingsService>();
    final billing = context.read<BillingProvider>();
    _invoiceDate = inv?.invoiceDate ?? DateTime.now();
    _invoiceNo = TextEditingController(
      text: inv?.invoiceNo ?? billing.nextInvoiceNo(settings.invoicePrefix, _invoiceDate),
    );
    _customerId = inv?.customerId;
    _buyerName = TextEditingController(text: inv?.buyerName);
    _buyerGstin = TextEditingController(text: inv?.buyerGstin);
    _buyerPhone = TextEditingController(text: inv?.buyerPhone);
    _buyerAddress = TextEditingController(text: inv?.buyerAddress);
    _buyerPlace = TextEditingController(text: inv?.buyerPlace);
    _buyerPincode = TextEditingController(text: inv?.buyerPincode);
    _paid = TextEditingController(
      text: inv == null || inv.paidAmount == 0 ? '' : BillingFormat.qty(inv.paidAmount),
    );
    _notes = TextEditingController(text: inv?.notes);
    _placeOfSupply = inv?.placeOfSupplyStateCode ?? settings.companyStateCode;
    _items = List.of(inv?.items ?? const <SalesInvoiceItem>[]);
  }

  @override
  void dispose() {
    for (final c in [
      _invoiceNo, _buyerName, _buyerGstin, _buyerPhone, _buyerAddress,
      _buyerPlace, _buyerPincode, _paid, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Refreshed from the watched SettingsService on every build (context.read is not allowed during build).
  int? _sellerState;

  bool get _interState =>
      GstCalculator.isInterState(sellerStateCode: _sellerState, placeOfSupplyStateCode: _placeOfSupply);

  GstInvoiceTotals get _totals =>
      GstCalculator.computeInvoice(_items.map((i) => i.gstInput).toList(), interState: _interState);

  // ---------- Buyer ----------

  Future<void> _pickCustomer() async {
    final customers = context.read<BookingProvider>().customers;
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CustomerPickerSheet(customers: customers),
    );
    if (picked == null) return;
    setState(() {
      _customerId = picked.id;
      _buyerName.text = picked.name;
      _buyerPhone.text = picked.phone;
      _buyerAddress.text = picked.address ?? '';
      _buyerGstin.text = picked.gstin ?? '';
      _buyerPlace.text = picked.city ?? '';
      _buyerPincode.text = picked.pincode ?? '';
      final state = picked.stateCode ??
          (picked.isGstRegistered ? GstMaster.stateCodeFromGstin(picked.gstin!) : null);
      if (state != null) _placeOfSupply = state;
    });
  }

  void _onGstinChanged(String value) {
    final g = GstMaster.normalizeGstin(value);
    if (g.length >= 2) {
      final state = GstMaster.stateCodeFromGstin(g);
      if (GstMaster.stateByCode(state) != null && state != _placeOfSupply) {
        setState(() => _placeOfSupply = state);
      }
    }
  }

  // ---------- Items ----------

  Future<void> _editItem({int? index}) async {
    final result = await showModalBottomSheet<SalesInvoiceItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ItemEditorSheet(item: index == null ? null : _items[index]),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
    });
  }

  // ---------- Save ----------

  Future<void> _save() async {
    final settings = context.read<SettingsService>();
    _sellerState = widget.invoice?.sellerStateCode ?? settings.companyStateCode;
    if (_sellerState == null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Company state missing'),
          content: const Text(
            'Set your company state (and GSTIN) in Settings > Company Profile so the app can decide between CGST+SGST and IGST.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Settings')),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        if (mounted) setState(() {});
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    setState(() => _saving = true);
    try {
      final billing = context.read<BillingProvider>();
      final invoiceNo = _invoiceNo.text.trim();
      if (await billing.invoiceNoTaken(invoiceNo, excludingId: widget.invoice?.id)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice number $invoiceNo is already used')),
        );
        return;
      }

      String? orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      final gstin = _buyerGstin.text.trim().isEmpty ? null : GstMaster.normalizeGstin(_buyerGstin.text);
      final existing = widget.invoice;

      final invoice = SalesInvoice(
        id: existing?.id,
        invoiceNo: invoiceNo,
        invoiceDate: _invoiceDate,
        customerId: _customerId,
        buyerName: _buyerName.text.trim(),
        buyerGstin: gstin,
        buyerPhone: orNull(_buyerPhone),
        buyerAddress: orNull(_buyerAddress),
        buyerPlace: orNull(_buyerPlace),
        buyerPincode: orNull(_buyerPincode),
        placeOfSupplyStateCode: _placeOfSupply!,
        sellerStateCode: existing?.sellerStateCode ?? settings.companyStateCode!,
        paidAmount: BillingFormat.parse(_paid.text) ?? 0,
        notes: orNull(_notes),
        transport: existing?.transport ?? const TransportDetails(),
        ewbNo: existing?.ewbNo,
        ewbDate: existing?.ewbDate,
        ewbValidUpto: existing?.ewbValidUpto,
        lastUpdated: DateTime.now(),
        items: _items,
      );
      final saved = await billing.saveInvoice(invoice);
      if (!mounted) return;
      if (widget.isEditing) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => InvoiceDetailsScreen(invoiceId: saved.id!)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    _sellerState = widget.invoice?.sellerStateCode ?? settings.companyStateCode;
    final totals = _totals;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          BillingHeader(title: widget.isEditing ? 'Edit Invoice' : 'New GST Invoice'),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (!settings.gstProfileComplete || settings.companyGstNumber.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Tip: fill in your company GSTIN, state, city and PIN code in Settings > Company Profile. '
                        'They are printed on the tax invoice and needed for e-way bills.',
                      ),
                    ),
                  if (widget.invoice?.hasEwayBill ?? false)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'E-way bill ${widget.invoice!.ewbNo} was generated for this invoice. If you change items or amounts, '
                        'cancel it on the portal (within 24 hours) and generate a new one.',
                      ),
                    ),
                  SectionCard(
                    title: 'Invoice',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _invoiceNo,
                            decoration: const InputDecoration(labelText: 'Invoice No'),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Required';
                              if (!RegExp(r'^[A-Za-z0-9/-]{1,16}$').hasMatch(t)) {
                                return 'Max 16: letters, digits, / -';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _invoiceDate,
                                firstDate: DateTime(2017, 7, 1),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _invoiceDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.event)),
                              child: Text(BillingFormat.date(_invoiceDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionCard(
                    title: 'Bill To',
                    trailing: TextButton.icon(
                      onPressed: _pickCustomer,
                      icon: const Icon(Icons.person_search_outlined, size: 18),
                      label: const Text('Select customer'),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _buyerName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Buyer name *'),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter buyer name' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _buyerGstin,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Buyer GSTIN',
                            helperText: 'Leave empty for unregistered (B2C) buyers',
                          ),
                          onChanged: _onGstinChanged,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) return null;
                            return GstMaster.validateGstin(v!);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _buyerPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _buyerAddress,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Address'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _buyerPlace,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(labelText: 'City / Place'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _buyerPincode,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: const InputDecoration(labelText: 'PIN code', counterText: ''),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  if (t.isEmpty) return null;
                                  return RegExp(r'^[1-9][0-9]{5}$').hasMatch(t) ? null : '6 digits';
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Align(alignment: Alignment.centerLeft, child: FieldLabel('Place of supply', required: true)),
                        GstStateDropdown(
                          value: _placeOfSupply,
                          required: true,
                          onChanged: (v) => setState(() => _placeOfSupply = v),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text(_interState ? 'Inter-state: IGST applies' : 'Intra-state: CGST + SGST apply'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionCard(
                    title: 'Items',
                    trailing: TextButton.icon(
                      onPressed: () => _editItem(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add item'),
                    ),
                    child: _items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('No items yet', style: TextStyle(color: Colors.grey[500])),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < _items.length; i++)
                                _ItemTile(
                                  item: _items[i],
                                  line: totals.lines[i],
                                  onTap: () => _editItem(index: i),
                                  onRemove: () => setState(() => _items.removeAt(i)),
                                ),
                            ],
                          ),
                  ),
                  SectionCard(
                    title: 'Totals',
                    child: Column(
                      children: [
                        TotalsRow('Taxable value', BillingFormat.money(totals.taxableValue)),
                        if (_interState) TotalsRow('IGST', BillingFormat.money(totals.igst)),
                        if (!_interState) TotalsRow('CGST', BillingFormat.money(totals.cgst)),
                        if (!_interState) TotalsRow('SGST', BillingFormat.money(totals.sgst)),
                        if (totals.roundOff != 0) TotalsRow('Round off', BillingFormat.money(totals.roundOff)),
                        const Divider(),
                        TotalsRow('Invoice total', BillingFormat.money(totals.grandTotal), strong: true),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paid,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount received', prefixText: '₹ '),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) return null;
                            final n = BillingFormat.parse(v!);
                            return (n == null || n < 0) ? 'Invalid amount' : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Notes (printed on invoice)'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(widget.isEditing ? 'Save Changes' : 'Save Invoice'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final SalesInvoiceItem item;
  final GstLineResult line;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ItemTile({required this.item, required this.line, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${BillingFormat.qty(item.quantity)} ${item.unit} × ${BillingFormat.money(item.rate)}'
                    '${item.priceIncludesTax ? ' incl.' : ''}'
                    '${item.discountPercent > 0 ? ' − ${GstCalculator.formatRate(item.discountPercent)}%' : ''}'
                    ' · HSN ${item.hsnCode} · GST ${GstCalculator.formatRate(item.gstRate)}%',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Text(BillingFormat.money(line.lineTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;

  const _CustomerPickerSheet({required this.customers});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = widget.customers
        .where((c) =>
            q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            (c.gstin ?? '').toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search name, phone or GSTIN',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No customers found. Add them from the Customers tab.'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())),
                          title: Text(c.name),
                          subtitle: Text(c.isGstRegistered ? '${c.phone} · ${c.gstin}' : c.phone),
                          onTap: () => Navigator.pop(context, c),
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

/// Add/edit one invoice line, optionally picking from the product master.
class _ItemEditorSheet extends StatefulWidget {
  final SalesInvoiceItem? item;

  const _ItemEditorSheet({this.item});

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _hsn = TextEditingController(text: widget.item?.hsnCode);
  late final _qty = TextEditingController(text: widget.item == null ? '1' : BillingFormat.qty(widget.item!.quantity));
  late final _rate = TextEditingController(text: widget.item == null ? '' : BillingFormat.qty(widget.item!.rate));
  late final _discount = TextEditingController(
    text: (widget.item?.discountPercent ?? 0) == 0 ? '' : BillingFormat.qty(widget.item!.discountPercent),
  );
  late String _unit = widget.item?.unit ?? 'NOS';
  late double _gstRate = widget.item?.gstRate ?? 18;
  late bool _inclusive = widget.item?.priceIncludesTax ?? false;
  late int? _productId = widget.item?.productId;
  bool _saveToProducts = false;

  @override
  void dispose() {
    _name.dispose();
    _hsn.dispose();
    _qty.dispose();
    _rate.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _applyProduct(Product p) {
    setState(() {
      _productId = p.id;
      _name.text = p.name;
      _hsn.text = p.hsnCode;
      _unit = p.unit;
      _rate.text = BillingFormat.qty(p.price);
      _gstRate = p.gstRate;
      _inclusive = p.priceIncludesTax;
      _saveToProducts = false;
    });
  }

  Future<void> _chooseProduct() async {
    final products = context.read<BillingProvider>().products;
    if (products.isEmpty) {
      final created = await showProductEditor(context);
      if (created != null) _applyProduct(created);
      return;
    }
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductPickerSheet(products: products),
    );
    if (picked != null) _applyProduct(picked);
  }

  Future<void> _done() async {
    if (!_formKey.currentState!.validate()) return;
    var productId = _productId;
    if (_saveToProducts && productId == null) {
      final saved = await context.read<BillingProvider>().saveProduct(Product(
            name: _name.text.trim(),
            hsnCode: _hsn.text.trim(),
            unit: _unit,
            price: BillingFormat.parse(_rate.text) ?? 0,
            gstRate: _gstRate,
            priceIncludesTax: _inclusive,
            lastUpdated: DateTime.now(),
          ));
      productId = saved.id;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      SalesInvoiceItem(
        productId: productId,
        name: _name.text.trim(),
        hsnCode: _hsn.text.trim(),
        unit: _unit,
        quantity: BillingFormat.parse(_qty.text) ?? 1,
        rate: BillingFormat.parse(_rate.text) ?? 0,
        discountPercent: BillingFormat.parse(_discount.text) ?? 0,
        gstRate: _gstRate,
        priceIncludesTax: _inclusive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item == null ? 'Add Item' : 'Edit Item',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _chooseProduct,
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text('From products'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Item name *'),
                  onChanged: (_) => _productId = null,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter item name' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hsn,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'HSN / SAC *'),
                        validator: (v) =>
                            RegExp(r'^[0-9]{4,8}$').hasMatch((v ?? '').trim()) ? null : '4-8 digits',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: GstMaster.units.keys
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v ?? 'NOS'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Qty *'),
                        validator: (v) {
                          final n = BillingFormat.parse(v ?? '');
                          return (n == null || n <= 0) ? '> 0' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _rate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Rate *', prefixText: '₹ '),
                        validator: (v) {
                          final n = BillingFormat.parse(v ?? '');
                          return (n == null || n < 0) ? 'Enter rate' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Discount %'),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) return null;
                          final n = BillingFormat.parse(v!);
                          return (n == null || n < 0 || n > 100) ? '0-100' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        value: GstMaster.gstRates.contains(_gstRate) ? _gstRate : 18,
                        decoration: const InputDecoration(labelText: 'GST %'),
                        items: GstMaster.gstRates
                            .map((r) => DropdownMenuItem(value: r, child: Text('${GstCalculator.formatRate(r)}%')))
                            .toList(),
                        onChanged: (v) => setState(() => _gstRate = v ?? 18),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rate includes GST'),
                  value: _inclusive,
                  onChanged: (v) => setState(() => _inclusive = v),
                ),
                if (_productId == null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Also save to products'),
                    value: _saveToProducts,
                    onChanged: (v) => setState(() => _saveToProducts = v ?? false),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _done,
                    icon: const Icon(Icons.check),
                    label: Text(widget.item == null ? 'Add to Invoice' : 'Update Item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;

  const _ProductPickerSheet({required this.products});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = widget.products
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.hsnCode.contains(q))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search products', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text('HSN ${p.hsnCode} · GST ${GstCalculator.formatRate(p.gstRate)}%'),
                    trailing: Text(BillingFormat.money(p.price)),
                    onTap: () => Navigator.pop(context, p),
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
