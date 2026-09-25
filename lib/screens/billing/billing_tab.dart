import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/billing_provider.dart';
import '../../theme/app_theme.dart';
import 'billing_widgets.dart';
import 'invoice_details_screen.dart';
import 'products_screen.dart';

/// Home-screen tab listing GST sales invoices with a monthly summary.
class BillingTab extends StatefulWidget {
  const BillingTab({super.key});

  @override
  State<BillingTab> createState() => _BillingTabState();
}

class _BillingTabState extends State<BillingTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, billing, _) {
        final month = billing.monthSummary(DateTime.now());
        final q = _query.toLowerCase();
        final invoices = billing.invoices
            .where((i) =>
                q.isEmpty ||
                i.invoiceNo.toLowerCase().contains(q) ||
                i.buyerName.toLowerCase().contains(q) ||
                (i.buyerGstin ?? '').toLowerCase().contains(q))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Sales this month', value: BillingFormat.money(month.sales))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'GST this month', value: BillingFormat.money(month.tax))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search invoice no, buyer or GSTIN',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Products',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductsScreen()),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!billing.isLoaded)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (invoices.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      billing.invoices.isEmpty ? 'No GST invoices yet. Tap "New Invoice" to create one.' : 'No matches',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              ...invoices.map((inv) {
                final total = inv.totals.grandTotal;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InvoiceDetailsScreen(invoiceId: inv.id!)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.buyerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${inv.invoiceNo} · ${BillingFormat.date(inv.invoiceDate)}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  if (inv.hasEwayBill)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'EWB ${inv.ewbNo}',
                                        style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  BillingFormat.money(total),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  inv.balanceAmount == 0 ? 'Paid' : 'Due ${BillingFormat.money(inv.balanceAmount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: inv.balanceAmount == 0 ? AppTheme.success : AppTheme.warning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
