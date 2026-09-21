import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// Shown at app launch when App Lock is enabled; unlocks with biometrics or device PIN.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _localAuth = LocalAuthentication();
  bool _authenticating = false;
  bool _checkingSupport = true;
  bool _deviceSupported = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSupportAndAuthenticate());
  }

  Future<void> _checkSupportAndAuthenticate() async {
    setState(() => _checkingSupport = true);
    bool supported = false;
    try {
      supported = await _localAuth.isDeviceSupported() || await _localAuth.canCheckBiometrics;
    } catch (_) {
      supported = false;
    }
    if (!mounted) return;
    setState(() {
      _deviceSupported = supported;
      _checkingSupport = false;
    });
    if (supported) {
      await _authenticate();
    } else {
      setState(() => _error = "Your phone doesn't have a screen lock or fingerprint set up, so App Lock can't verify you.");
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Rental Manager',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (authenticated) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Authentication cancelled');
      }
    } catch (e) {
      setState(() => _error = 'Unable to authenticate: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _disableAppLock() async {
    await context.read<SettingsService>().setAppLockEnabled(false);
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'Rental Manager',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Locked for your privacy',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (_checkingSupport)
                const CircularProgressIndicator(color: Colors.white)
              else ...[
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
                if (_deviceSupported)
                  ElevatedButton.icon(
                    onPressed: _authenticating ? null : _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(_authenticating ? 'Authenticating...' : 'Unlock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _disableAppLock,
                  child: const Text('Turn off App Lock', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

