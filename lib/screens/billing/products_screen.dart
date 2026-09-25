import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gst/gst_calculator.dart';
import '../../gst/gst_master.dart';
import '../../models/product.dart';
import '../../services/billing_provider.dart';
import '../../theme/app_theme.dart';
import 'billing_widgets.dart';

/// Product master: items with HSN, unit, price and GST rate.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showProductEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          const BillingHeader(title: 'Products'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or HSN',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: Consumer<BillingProvider>(
              builder: (context, billing, _) {
                final products = billing.products
                    .where((p) => _query.isEmpty || p.name.toLowerCase().contains(_query) || p.hsnCode.contains(_query))
                    .toList();
                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        billing.products.isEmpty
                            ? 'No products yet.\nAdd the items you sell with their HSN code and GST rate.'
                            : 'No products match your search',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${p.isService ? 'SAC' : 'HSN'} ${p.hsnCode} · ${p.unit} · GST ${GstCalculator.formatRate(p.gstRate)}%'
                          '${p.priceIncludesTax ? ' (incl.)' : ''}',
                        ),
                        trailing: Text(
                          BillingFormat.money(p.price),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                        ),
                        onTap: () => showProductEditor(context, product: p),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the add/edit product sheet. Returns the saved product, or null.
Future<Product?> showProductEditor(BuildContext context, {Product? product, String? initialName}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ProductEditorSheet(product: product, initialName: initialName),
  );
}

class _ProductEditorSheet extends StatefulWidget {
  final Product? product;
  final String? initialName;

  const _ProductEditorSheet({this.product, this.initialName});

  @override
  State<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<_ProductEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? widget.initialName);
  late final _hsn = TextEditingController(text: widget.product?.hsnCode);
  late final _price = TextEditingController(
    text: widget.product == null ? '' : BillingFormat.qty(widget.product!.price),
  );
  late String _unit = widget.product?.unit ?? 'NOS';
  late double _gstRate = widget.product?.gstRate ?? 18;
  late bool _inclusive = widget.product?.priceIncludesTax ?? false;

  @override
  void dispose() {
    _name.dispose();
    _hsn.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      hsnCode: _hsn.text.trim(),
      unit: _unit,
      price: BillingFormat.parse(_price.text) ?? 0,
      gstRate: _gstRate,
      priceIncludesTax: _inclusive,
      lastUpdated: DateTime.now(),
    );
    final saved = await context.read<BillingProvider>().saveProduct(product);
    if (!mounted) return;
    Navigator.pop(context, saved);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('Existing invoices keep their copy of this item.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<BillingProvider>().deleteProduct(widget.product!.id!);
    if (mounted) Navigator.pop(context);
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.product == null ? 'Add Product' : 'Edit Product',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (widget.product != null)
                      IconButton(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                        tooltip: 'Delete',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('Product / Service name', required: true),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('HSN / SAC', required: true),
                          TextFormField(
                            controller: _hsn,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'e.g. 8471'),
                            validator: (v) {
                              final d = (v ?? '').trim();
                              if (!RegExp(r'^[0-9]{4,8}$').hasMatch(d)) return '4-8 digits';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Unit'),
                          DropdownButtonFormField<String>(
                            value: _unit,
                            isExpanded: true,
                            items: GstMaster.units.entries
                                .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} - ${e.value}')))
                                .toList(),
                            onChanged: (v) => setState(() => _unit = v ?? 'NOS'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Selling price', required: true),
                          TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '₹ '),
                            validator: (v) {
                              final n = BillingFormat.parse(v ?? '');
                              return (n == null || n < 0) ? 'Enter a price' : null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('GST rate'),
                          DropdownButtonFormField<double>(
                            value: GstMaster.gstRates.contains(_gstRate) ? _gstRate : 18,
                            items: GstMaster.gstRates
                                .map((r) => DropdownMenuItem(value: r, child: Text('${GstCalculator.formatRate(r)}%')))
                                .toList(),
                            onChanged: (v) => setState(() => _gstRate = v ?? 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Price includes GST'),
                  subtitle: const Text('Turn on if the selling price is the final MRP-style price'),
                  value: _inclusive,
                  onChanged: (v) => setState(() => _inclusive = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Save Product'),
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
