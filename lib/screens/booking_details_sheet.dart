import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking.dart';
import '../services/booking_provider.dart';
import '../services/invoice_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/delivery_style.dart';
import 'add_booking_screen.dart';

/// Bottom sheet showing full booking details with edit/delete/bill actions.
/// Shared between the dashboard and the customer bookings list.
class BookingDetailsSheet extends StatelessWidget {
  final Booking booking;

  const BookingDetailsSheet({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final currentBooking = provider.getBooking(booking.id!) ?? booking;
        final customer = provider.getCustomer(currentBooking.customerId);
        final delivery = provider.getDeliveryForBooking(currentBooking.id);
        final style = deliveryStatusStyle(delivery?.status ?? 'pending');

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Booking Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: style.$2.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      style.$1,
                      style: TextStyle(color: style.$2, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow('Customer', customer?.name ?? 'Unknown'),
              if (customer != null) _DetailRow('Phone', customer.phone),
              _DetailRow('Event Date', '${currentBooking.eventDate.day}/${currentBooking.eventDate.month}/${currentBooking.eventDate.year}'),
              if (currentBooking.specialNotes != null && currentBooking.specialNotes!.isNotEmpty)
                _DetailRow('Notes', currentBooking.specialNotes!),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _AmountRow('Rent Amount', currentBooking.totalAmount - currentBooking.depositAmount),
                    _AmountRow('Security Deposit', currentBooking.depositAmount),
                    const Divider(height: 18),
                    _AmountRow('Total Amount', currentBooking.totalAmount, bold: true),
                    const Divider(height: 18),
                    _AmountRow('Paid Amount', currentBooking.paidAmount),
                    const SizedBox(height: 12),
                    _AmountRow('Balance Due', currentBooking.balanceAmount, bold: true, color: currentBooking.balanceAmount == 0 ? AppTheme.success : AppTheme.warning),
                    const SizedBox(height: 6),
                    Text(
                      currentBooking.balanceAmount == 0 ? 'Fully Paid' : 'Balance Pending',
                      style: TextStyle(
                        color: currentBooking.balanceAmount == 0 ? AppTheme.success : AppTheme.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Items (${currentBooking.items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (currentBooking.items.isEmpty)
                Text('No items added', style: TextStyle(color: Colors.grey[500]))
              else
                ...currentBooking.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${item.itemName} (${item.category ?? '-'}) · Qty: ${item.quantity}'),
                  ),
                ),
              const SizedBox(height: 20),
              if (currentBooking.balanceAmount > 0)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await provider.markBalancePaid(currentBooking.id!);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark Balance as Paid'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.success,
                      side: const BorderSide(color: AppTheme.success),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: customer == null
                      ? null
                      : () async {
                          final settings = context.read<SettingsService>();
                          await InvoiceService.generateAndShare(
                            booking: currentBooking,
                            customer: customer,
                            settings: settings,
                          );
                        },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Generate Bill'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddBookingScreen(booking: currentBooking)),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Booking'),
                            content: const Text('Are you sure you want to delete this booking? This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          if (!context.mounted) return;
                          await provider.deleteBooking(currentBooking.id!);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final Color? color;

  const _AmountRow(this.label, this.amount, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (bold ? AppTheme.primaryDark : Colors.black87),
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
