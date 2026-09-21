import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'services/booking_provider.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.initialize();

  runApp(const RentManApp());
}

class RentManApp extends StatelessWidget {
  const RentManApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => SettingsService()..load()),
      ],
      child: MaterialApp(
        title: 'RentMan - by GellSoft',
        theme: AppTheme.themeData,
        home: const AppGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class CopyBlockedScreen extends StatelessWidget {
  const CopyBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'App Restricted',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 72, color: Colors.redAccent),
                SizedBox(height: 20),
                Text(
                  'This app is not authorized on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Please install it on the original licensed device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
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

/// Shows the lock screen first when App Lock is enabled, otherwise the dashboard.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final settings = context.read<SettingsService>();
      if (settings.appLockEnabled) {
        setState(() => _unlocked = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Bookings may have crossed into their alert window while backgrounded.
      final settings = context.read<SettingsService>();
      context.read<BookingProvider>().syncAllPendingOrderAlerts(settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        if (!settings.isLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (settings.appLockEnabled && !_unlocked) {
          return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
        }
        return const HomeScreen();
      },
    );
  }
}

