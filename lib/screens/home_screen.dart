import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/booking_provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/delivery_style.dart';
import 'add_booking_screen.dart';
import 'add_customer_screen.dart';
import 'billing/billing_tab.dart';
import 'billing/create_invoice_screen.dart';
import 'backup_sync_screen.dart';
import 'booking_details_sheet.dart';
import 'customer_list_screen.dart';
import 'delivery_tracking_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load data when app starts
    Future.microtask(() async {
      if (!mounted) return;
      final provider = context.read<BookingProvider>();
      await provider.loadAllData();
      if (!mounted) return;
      // Bookings may have crossed into their alert window while the app was closed.
      await provider.syncAllPendingOrderAlerts(context.read<SettingsService>());
    });
  }

  static const _titles = ['Dashboard', 'Customers', 'Delivery Tracking', 'GST Billing'];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final headerSubtitle = settings.companyName.isNotEmpty ? settings.companyName : 'Rental Management';
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          GradientHeader(
            height: 132,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerSubtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _titles[_selectedIndex],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BackupSyncScreen()),
                        );
                      },
                      icon: const Icon(Icons.cloud_sync_outlined, color: Colors.white),
                      tooltip: 'Backup & Sync',
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Delivery',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Billing',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => switch (_selectedIndex) {
                      1 => const AddCustomerScreen(),
                      3 => const CreateInvoiceScreen(),
                      _ => const AddBookingScreen(),
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(switch (_selectedIndex) {
                1 => 'Add Customer',
                3 => 'New Invoice',
                _ => 'Add Booking',
              }),
            ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardTab();
      case 1:
        return const CustomerListScreen();
      case 2:
        return const DeliveryTrackingScreen();
      case 3:
        return const BillingTab();
      default:
        return const DashboardTab();
    }
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final pendingReminders = provider.pendingDeliveries;
        final totalCustomers = provider.customers.length;
        final totalBookings = provider.bookings.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Customers',
                      value: totalCustomers.toString(),
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF4A90E2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Bookings',
                      value: totalBookings.toString(),
                      icon: Icons.event_available_rounded,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Pending',
                      value: pendingReminders.length.toString(),
                      icon: Icons.notifications_active_rounded,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Upcoming Deliveries
              const _SectionHeader(
                title: 'Upcoming Deliveries',
                subtitle: 'Rentals in the next 5-10 days',
              ),
              const SizedBox(height: 12),

              if (pendingReminders.isEmpty)
                const _EmptyState(
                  icon: Icons.event_busy_rounded,
                  message: 'No pending deliveries',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingReminders.length,
                  itemBuilder: (context, index) {
                    final booking = pendingReminders[index];
                    final customer = provider.getCustomer(booking.customerId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeliveryTrackingScreen(
                                  bookingId: booking.id,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${booking.daysUntilRental}d',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer?.name ?? 'Unknown Customer',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${booking.items.length} items · Rental ${booking.rentalDate.day}/${booking.rentalDate.month}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              // Recently Updated Deliveries
              if (provider.updatedDeliveries.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Delivery Updates',
                  subtitle: 'Already dispatched, delivered or returned',
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.updatedDeliveries.length.clamp(0, 5),
                  itemBuilder: (context, index) {
                    final booking = provider.updatedDeliveries[index];
                    final customer = provider.getCustomer(booking.customerId);
                    final delivery = provider.getDeliveryForBooking(booking.id);
                    final style = deliveryStatusStyle(delivery?.status ?? 'pending');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeliveryTrackingScreen(
                                  bookingId: booking.id,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: style.$2.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(style.$3, color: style.$2, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer?.name ?? 'Unknown Customer',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rental ${booking.rentalDate.day}/${booking.rentalDate.month}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
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
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
              ],

              // Recent Bookings
              const _SectionHeader(title: 'Recent Bookings'),
              const SizedBox(height: 12),

              if (provider.bookings.isEmpty)
                const _EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: 'No bookings yet',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.bookings.length.clamp(0, 5),
                  itemBuilder: (context, index) {
                    final booking = provider.bookings[index];
                    final customer = provider.getCustomer(booking.customerId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (_) => BookingDetailsSheet(booking: booking),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                                  child: Text(
                                    (customer?.name.isNotEmpty ?? false) ? customer!.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(customer?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text('${booking.items.length} items', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${booking.balanceAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[900],
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

