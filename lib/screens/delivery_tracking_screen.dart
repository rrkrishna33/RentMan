import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/delivery.dart';
import '../services/booking_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class DeliveryTrackingScreen extends StatelessWidget {
  final int? bookingId;

  const DeliveryTrackingScreen({super.key, this.bookingId});

  @override
  Widget build(BuildContext context) {
    if (bookingId != null) {
      return _DeliveryDetailScreen(bookingId: bookingId!);
    }
    return const _DeliveryListScreen();
  }
}

// ==================== STATUS HELPERS ====================

class _StatusStyle {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusStyle(this.label, this.color, this.icon);
}

const Map<String, _StatusStyle> _statusStyles = {
  'pending': _StatusStyle('Pending', AppTheme.warning, Icons.schedule_rounded),
  'dispatched': _StatusStyle('Dispatched', Color(0xFF4A90E2), Icons.local_shipping_rounded),
  'delivered': _StatusStyle('Delivered', AppTheme.success, Icons.check_circle_rounded),
  'returned': _StatusStyle('Returned', AppTheme.danger, Icons.assignment_return_rounded),
};

_StatusStyle _styleFor(String status) => _statusStyles[status] ?? _statusStyles['pending']!;

const Map<String, String> _returnConditions = {
  'good': 'Good Condition',
  'damaged': 'Damaged',
  'missing': 'Missing Items',
};

// ==================== LIST VIEW (Delivery tab) ====================

class _DeliveryListScreen extends StatelessWidget {
  const _DeliveryListScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          final awaiting = provider.bookings.where((b) {
            final status = provider.getDeliveryForBooking(b.id)?.status ?? 'pending';
            return status == 'pending';
          }).toList()
            ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

          final updated = provider.updatedDeliveries;

          if (provider.bookings.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                SizedBox(height: 60),
                Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('No bookings yet', style: TextStyle(color: Colors.grey))),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            children: [
              Text('Awaiting Dispatch (${awaiting.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (awaiting.isEmpty)
                _emptyHint('Every booking has been dispatched')
              else
                ...awaiting.map((b) => _BookingTile(booking: b, provider: provider)),

              const SizedBox(height: 26),
              Text('Status Updated (${updated.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (updated.isEmpty)
                _emptyHint('No deliveries dispatched yet')
              else
                ...updated.map((b) => _BookingTile(booking: b, provider: provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyHint(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text(text, style: TextStyle(color: Colors.grey[500]))),
      );
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  final BookingProvider provider;

  const _BookingTile({required this.booking, required this.provider});

  @override
  Widget build(BuildContext context) {
    final customer = provider.getCustomer(booking.customerId);
    final status = provider.getDeliveryForBooking(booking.id)?.status ?? 'pending';
    final style = _styleFor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DeliveryTrackingScreen(bookingId: booking.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer?.name ?? 'Unknown Customer',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        'Event ${booking.eventDate.day}/${booking.eventDate.month}/${booking.eventDate.year} · ${booking.items.length} items',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    style.label,
                    style: TextStyle(color: style.color, fontWeight: FontWeight.w600, fontSize: 12),
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

// ==================== DETAIL VIEW (view/update a booking's delivery) ====================

class _DeliveryDetailScreen extends StatefulWidget {
  final int bookingId;
  const _DeliveryDetailScreen({required this.bookingId});

  @override
  State<_DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<_DeliveryDetailScreen> {
  final _courierController = TextEditingController();
  final _trackingController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedStatus = 'pending';
  String _returnCondition = 'good';
  List<String> _photoPaths = [];
  bool _prefilled = false;

  @override
  void dispose() {
    _courierController.dispose();
    _trackingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillOnce(BookingProvider provider) {
    if (_prefilled) return;
    final existing = provider.getDeliveryForBooking(widget.bookingId);
    if (existing != null) {
      _courierController.text = existing.courierName ?? '';
      _trackingController.text = existing.trackingNumber ?? '';
      _notesController.text = existing.notes ?? '';
      _selectedStatus = existing.status;
      _returnCondition = existing.returnCondition ?? 'good';
      _photoPaths = List<String>.from(existing.packingPhotos);
    }
    _prefilled = true;
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.primary),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final picker = ImagePicker();
    final pickedFiles = source == ImageSource.gallery
        ? await picker.pickMultiImage(imageQuality: 75)
        : [if (await picker.pickImage(source: ImageSource.camera, imageQuality: 75) case final picked) picked];
    if (pickedFiles.isEmpty) return;

    final savedPaths = <String>[];
    for (var index = 0; index < pickedFiles.length; index++) {
      final pickedFile = pickedFiles[index];
      if (pickedFile == null) continue;
      final fileName = 'pack_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final savedPath = '${dir.path}/$fileName';
      await File(pickedFile.path).copy(savedPath);
      savedPaths.add(savedPath);
    }

    setState(() => _photoPaths.addAll(savedPaths));
    if (!mounted) return;
    await context.read<BookingProvider>().savePackingPhotos(widget.bookingId, _photoPaths);
  }

  Future<void> _removePhoto(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text('This photo will be deleted permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final path = _photoPaths[index];
    setState(() => _photoPaths.removeAt(index));
    if (!mounted) return;
    await context.read<BookingProvider>().savePackingPhotos(widget.bookingId, _photoPaths);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _viewPhoto(String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.file(File(path))),
      ),
    );
  }

  void _submitDelivery() async {
    try {
      await context.read<BookingProvider>().updateDeliveryStatus(
            bookingId: widget.bookingId,
            courierName: _courierController.text,
            trackingNumber: _trackingController.text,
            status: _selectedStatus,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            returnCondition: _selectedStatus == 'returned' ? _returnCondition : null,
          );

      if (!mounted) return;

      if (_selectedStatus == 'dispatched') {
        await NotificationService.showDeliveryNotification(
          courierName: _courierController.text,
          trackingNumber: _trackingController.text,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${_styleFor(_selectedStatus).label}')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
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
                  'Delivery Details',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<BookingProvider>(
              builder: (context, provider, _) {
                final booking = provider.getBooking(widget.bookingId);
                if (booking == null) {
                  return const Center(child: Text('Booking not found'));
                }
                final customer = provider.getCustomer(booking.customerId);
                final delivery = provider.getDeliveryForBooking(booking.id);
                _prefillOnce(provider);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bookingDetailsCard(booking, customer?.name, customer?.phone, delivery),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          const Text('Packing Photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          if (_photoPaths.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${_photoPaths.length}',
                                  style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Photograph the gathered items before packing so they\'re easy to identify at dispatch',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ..._photoPaths.asMap().entries.map((entry) {
                              final index = entry.key;
                              final path = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _viewPhoto(path),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.file(
                                          File(path),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removePhoto(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            InkWell(
                              onTap: _addPhoto,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.4), style: BorderStyle.solid),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, color: AppTheme.primary, size: 22),
                                    SizedBox(height: 4),
                                    Text('Add', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),

                      const Text('Delivery Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: _statusStyles.keys
                            .map((value) => _StatusCard(
                                  _styleFor(value).label,
                                  value,
                                  _selectedStatus,
                                  onTap: (v) => setState(() => _selectedStatus = v),
                                ))
                            .toList(),
                      ),

                      if (_selectedStatus == 'returned') ...[
                        const SizedBox(height: 22),
                        const Text('Return Condition', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _returnConditions.entries.map((entry) {
                            final isSelected = _returnCondition == entry.key;
                            return ChoiceChip(
                              label: Text(entry.value),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _returnCondition = entry.key),
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 26),

                      const Text('Courier Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _courierController,
                        decoration: const InputDecoration(
                          hintText: 'Courier name',
                          prefixIcon: Icon(Icons.delivery_dining_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _trackingController,
                        decoration: const InputDecoration(
                          hintText: 'Tracking number',
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text('Notes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Add delivery notes...',
                        ),
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitDelivery,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Update Delivery Status'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingDetailsCard(Booking booking, String? customerName, String? customerPhone, Delivery? delivery) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  (customerName?.isNotEmpty ?? false) ? customerName![0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName ?? 'Unknown Customer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    if (customerPhone != null)
                      Text(customerPhone, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _detailRow(Icons.event_rounded, 'Event Date',
              '${booking.eventDate.day}/${booking.eventDate.month}/${booking.eventDate.year}'),
          const SizedBox(height: 10),
          _detailRow(Icons.currency_rupee_rounded, 'Deposit', booking.depositAmount.toStringAsFixed(0)),
          if (booking.specialNotes != null && booking.specialNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRow(Icons.notes_rounded, 'Notes', booking.specialNotes!),
          ],
          if (delivery?.returnDate != null) ...[
            const SizedBox(height: 10),
            _detailRow(Icons.assignment_return_rounded, 'Returned On',
                '${delivery!.returnDate!.day}/${delivery.returnDate!.month}/${delivery.returnDate!.year}'),
            const SizedBox(height: 10),
            _detailRow(Icons.fact_check_rounded, 'Condition',
                _returnConditions[delivery.returnCondition] ?? 'Good Condition'),
          ],
          const SizedBox(height: 14),
          Text('Items (${booking.items.length})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: booking.items
                .map((item) => ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Chip(
                        label: Text(
                          '${item.itemName} x${item.quantity}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        backgroundColor: AppTheme.background,
                        side: BorderSide.none,
                        labelStyle: const TextStyle(fontSize: 12.5),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13.5)),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final String currentStatus;
  final ValueChanged<String> onTap;

  const _StatusCard(this.label, this.value, this.currentStatus, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == currentStatus;
    final style = _styleFor(value);

    return Material(
      color: isSelected ? style.color : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(value),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                style.icon,
                size: 30,
                color: isSelected ? Colors.white : style.color,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
