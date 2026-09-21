import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/booking_provider.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../models/booking.dart';
import '../theme/app_theme.dart';
import 'add_customer_screen.dart';

class AddBookingScreen extends StatefulWidget {
  final int? customerId;
  final Booking? booking;

  const AddBookingScreen({super.key, this.customerId, this.booking});

  bool get isEditing => booking != null;

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late int _selectedCustomerId;
  late DateTime _selectedRentalDate;
  late TextEditingController _totalController;
  late TextEditingController _depositController;
  late TextEditingController _paidController;
  late TextEditingController _notesController;
  
  List<BookingItem> _items = [];

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;
    _selectedCustomerId = booking?.customerId ?? widget.customerId ?? 0;
    _selectedRentalDate = booking?.rentalDate ?? DateTime.now().add(const Duration(days: 7));
    // For editing: extract rent amount (total - deposit), for new bookings: use empty
    final rentAmount = booking != null ? (booking.totalAmount - booking.depositAmount) : 0.0;
    _totalController = TextEditingController(
      text: booking != null ? rentAmount.toStringAsFixed(0) : '',
    );
    _depositController = TextEditingController(
      text: booking != null ? booking.depositAmount.toStringAsFixed(0) : '',
    );
    _paidController = TextEditingController(
      text: booking != null ? booking.paidAmount.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: booking?.specialNotes ?? '');
    _items = booking != null ? List<BookingItem>.from(booking.items) : [];
  }

  @override
  void dispose() {
    _totalController.dispose();
    _depositController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addItem() {
    final categories = context.read<SettingsService>().categories;
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(categories: categories),
    ).then((item) {
      if (item != null) {
        setState(() => _items.add(item));
      }
    });
  }

  double _toMoney(TextEditingController controller) => double.tryParse(controller.text.trim()) ?? 0;

  double get _computedTotalAmount => _toMoney(_totalController) + _toMoney(_depositController);

  double get _balanceAmount {
    final total = _computedTotalAmount;
    final paid = _toMoney(_paidController);
    final balance = total - paid;
    return balance < 0 ? 0 : balance;
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedCustomerId != 0) {
      try {
        final provider = context.read<BookingProvider>();
        final settings = context.read<SettingsService>();
        int bookingId;
        if (widget.isEditing) {
          bookingId = widget.booking!.id!;
          await provider.updateBooking(
            id: bookingId,
            customerId: _selectedCustomerId,
            rentalDate: _selectedRentalDate,
            bookingDate: widget.booking!.bookingDate,
            totalAmount: _computedTotalAmount,
            depositAmount: _toMoney(_depositController),
            paidAmount: _toMoney(_paidController),
            items: _items,
            specialNotes: _notesController.text.isEmpty ? null : _notesController.text,
          );
          await NotificationService.cancelPendingOrderAlert(bookingId);
        } else {
          bookingId = await provider.addBooking(
            customerId: _selectedCustomerId,
            rentalDate: _selectedRentalDate,
            totalAmount: _computedTotalAmount,
            depositAmount: _toMoney(_depositController),
            paidAmount: _toMoney(_paidController),
            items: _items,
            specialNotes: _notesController.text.isEmpty ? null : _notesController.text,
          );
        }

        final deliveryStatus = provider.getDeliveryForBooking(bookingId)?.status ?? 'pending';
        if (settings.pendingOrderAlertsEnabled && deliveryStatus == 'pending') {
          final customer = provider.getCustomer(_selectedCustomerId);
          final booking = provider.getBooking(bookingId);
          if (customer != null && booking != null) {
            await NotificationService.schedulePendingOrderAlert(
              booking: booking,
              customerName: customer.name,
              intervalHours: settings.pendingOrderAlertIntervalHours,
            );
          }
        }

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEditing ? 'Booking updated successfully!' : 'Booking added successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
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
                  widget.isEditing ? 'Edit Booking' : 'Add Booking',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<BookingProvider>(
              builder: (context, provider, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Selection
                        const _FieldLabel('Select Customer', required: true),
                        const SizedBox(height: 8),
                        if (provider.customers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('No customers yet. Add a customer first.'),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Add Customer'),
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            value: _selectedCustomerId == 0 ? null : _selectedCustomerId,
                            isExpanded: true,
                            items: provider.customers.map((customer) {
                              return DropdownMenuItem(
                                value: customer.id,
                                child: Text(customer.name),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCustomerId = value ?? 0),
                            decoration: const InputDecoration(
                              hintText: 'Choose a customer',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value == 0) {
                                return 'Please select a customer';
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 18),

                        // Rental Date
                        const _FieldLabel('Rental Date', required: true),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedRentalDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() => _selectedRentalDate = date);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: AppTheme.primary, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  '${_selectedRentalDate.day}/${_selectedRentalDate.month}/${_selectedRentalDate.year}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Total Amount
                        const _FieldLabel('Rent Amount (₹)', required: true),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _totalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter total rent amount',
                            prefixIcon: Icon(Icons.receipt_long_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter total amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Security Deposit
                        const _FieldLabel('Security Deposit (₹)', required: true),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _depositController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter security deposit based on product value',
                            prefixIcon: Icon(Icons.currency_rupee_rounded),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter security deposit';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        const _FieldLabel('Paid Amount (₹)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _paidController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter amount already paid by customer',
                            prefixIcon: Icon(Icons.check_circle_outline),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Balance Due', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '₹${_balanceAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Items
                        const _FieldLabel('Items', required: true),
                        const SizedBox(height: 8),
                        if (_items.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text('No items added yet', style: TextStyle(color: Colors.grey[500])),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('${item.category} · Qty: ${item.quantity}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                                    onPressed: () => setState(() => _items.removeAt(index)),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: AppTheme.primary),
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Notes
                        const _FieldLabel('Special Notes'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Add any special instructions...',
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submitForm,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(widget.isEditing ? 'Save Changes' : 'Add Booking'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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

class _AddItemDialog extends StatefulWidget {
  final List<String> categories;

  const _AddItemDialog({required this.categories});

  @override
  State<_AddItemDialog> createState() => __AddItemDialogState();
}

class __AddItemDialogState extends State<_AddItemDialog> {
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  late String _selectedCategory = widget.categories.isNotEmpty ? widget.categories.first : '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _itemNameController,
            decoration: const InputDecoration(hintText: 'Item name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory.isEmpty ? null : _selectedCategory,
            items: widget.categories.map((cat) {
              return DropdownMenuItem(value: cat, child: Text(cat));
            }).toList(),
            onChanged: (value) => setState(() => _selectedCategory = value ?? ''),
            decoration: const InputDecoration(hintText: 'Category'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Quantity'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final item = BookingItem(
              bookingId: 0,
              itemName: _itemNameController.text,
              category: _selectedCategory,
              quantity: int.tryParse(_quantityController.text) ?? 1,
            );
            Navigator.pop(context, item);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
