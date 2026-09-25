import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gst/gst_calculator.dart';
import '../../gst/gst_master.dart';
import '../../models/sales_invoice.dart';
import '../../services/billing_provider.dart';
import '../../services/gst_invoice_pdf_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import 'billing_widgets.dart';
import 'create_invoice_screen.dart';
import 'eway_bill_screen.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final int invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  Future<void> _recordPayment(BuildContext context, SalesInvoice invoice) async {
    final controller = TextEditingController(text: BillingFormat.qty(invoice.balanceAmount));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record payment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount received now', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, BillingFormat.parse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's closing animation may still be using it.
    if (amount == null || amount <= 0 || !context.mounted) return;
    await context
        .read<BillingProvider>()
        .updateInvoiceHeader(invoice.copyWith(paidAmount: round2(invoice.paidAmount + amount)));
  }

  Future<void> _delete(BuildContext context, SalesInvoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text(
          'Invoice ${invoice.invoiceNo} will be removed from this app.'
          '${invoice.hasEwayBill ? '\n\nThe e-way bill ${invoice.ewbNo} is NOT cancelled automatically - cancel it on the portal.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<BillingProvider>().deleteInvoice(invoice.id!);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _runPdf(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BillingProvider, SettingsService>(
      builder: (context, billing, settings, _) {
        final invoice = billing.getInvoice(invoiceId);
        if (invoice == null) {
          return const Scaffold(body: Center(child: Text('Invoice not found')));
        }
        final totals = invoice.totals;
        final inter = totals.interState;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Column(
            children: [
              BillingHeader(
                title: invoice.invoiceNo,
                actions: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoice: invoice)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: () => _delete(context, invoice),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    SectionCard(
                      title: invoice.buyerName,
                      trailing: Chip(label: Text(invoice.isB2B ? 'B2B' : 'B2C')),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _info('Invoice date', BillingFormat.date(invoice.invoiceDate)),
                          if (invoice.isB2B) _info('GSTIN', invoice.buyerGstin!),
                          if ((invoice.buyerPhone ?? '').isNotEmpty) _info('Phone', invoice.buyerPhone!),
                          _info('Place of supply', GstMaster.stateLabel(invoice.placeOfSupplyStateCode)),
                          _info('Tax type', inter ? 'IGST (inter-state)' : 'CGST + SGST (intra-state)'),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _runPdf(context, () => GstInvoicePdfService.printOrPreview(invoice, settings)),
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Print / Preview'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _runPdf(context, () => GstInvoicePdfService.share(invoice, settings)),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share PDF'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _EwayBillCard(invoice: invoice),
                    SectionCard(
                      title: 'Items (${invoice.items.length})',
                      child: Column(
                        children: [
                          for (var i = 0; i < invoice.items.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(invoice.items[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text(
                                          '${BillingFormat.qty(invoice.items[i].quantity)} ${invoice.items[i].unit} × '
                                          '${BillingFormat.money(invoice.items[i].rate)} · HSN ${invoice.items[i].hsnCode} · '
                                          'GST ${GstCalculator.formatRate(invoice.items[i].gstRate)}%',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(BillingFormat.money(totals.lines[i].lineTotal)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Amount',
                      child: Column(
                        children: [
                          TotalsRow('Taxable value', BillingFormat.money(totals.taxableValue)),
                          if (inter) TotalsRow('IGST', BillingFormat.money(totals.igst)),
                          if (!inter) TotalsRow('CGST', BillingFormat.money(totals.cgst)),
                          if (!inter) TotalsRow('SGST', BillingFormat.money(totals.sgst)),
                          if (totals.roundOff != 0) TotalsRow('Round off', BillingFormat.money(totals.roundOff)),
                          const Divider(),
                          TotalsRow('Invoice total', BillingFormat.money(totals.grandTotal), strong: true),
                          TotalsRow('Received', BillingFormat.money(invoice.paidAmount)),
                          TotalsRow(
                            'Balance due',
                            BillingFormat.money(invoice.balanceAmount),
                            strong: true,
                            color: invoice.balanceAmount == 0 ? AppTheme.success : AppTheme.warning,
                          ),
                          if (invoice.balanceAmount > 0) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _recordPayment(context, invoice),
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Record payment'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if ((invoice.notes ?? '').isNotEmpty)
                      SectionCard(title: 'Notes', child: Text(invoice.notes!)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600]))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

class _EwayBillCard extends StatelessWidget {
  final SalesInvoice invoice;

  const _EwayBillCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final has = invoice.hasEwayBill;
    return SectionCard(
      title: 'E-Way Bill',
      trailing: Icon(
        has ? Icons.verified_outlined : Icons.local_shipping_outlined,
        color: has ? AppTheme.success : Colors.grey,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (has) ...[
            Text('EWB No: ${invoice.ewbNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (invoice.ewbDate != null) Text('Generated: ${BillingFormat.date(invoice.ewbDate!)}'),
            if (invoice.ewbValidUpto != null) Text('Valid until: ${BillingFormat.date(invoice.ewbValidUpto!)}'),
          ] else
            Text(
              invoice.totals.grandTotal >= 50000
                  ? 'Not generated yet. Needed before goods worth over ₹50,000 move.'
                  : 'Not generated. Usually not required below ₹50,000.',
              style: TextStyle(color: Colors.grey[700]),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EwayBillScreen(invoiceId: invoice.id!)),
              ),
              icon: const Icon(Icons.description_outlined),
              label: Text(has ? 'View / update e-way bill' : 'Prepare e-way bill'),
            ),
          ),
        ],
      ),
    );
  }
}
