import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../services/booking_provider.dart';
import '../services/drive_sync_service.dart';
import '../theme/app_theme.dart';

class BackupSyncScreen extends StatefulWidget {
  const BackupSyncScreen({super.key});

  @override
  State<BackupSyncScreen> createState() => _BackupSyncScreenState();
}

class _BackupSyncScreenState extends State<BackupSyncScreen> {
  final _driveSync = DriveSyncService();

  GoogleSignInAccount? _account;
  DateTime? _lastLocalSync;
  DateTime? _remoteBackupTime;
  bool _loadingAccount = true;
  bool _busy = false;
  String? _busyLabel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final account = await _driveSync.signInSilently();
    final lastSync = await _driveSync.getLastLocalSyncTime();
    setState(() {
      _account = account;
      _lastLocalSync = lastSync;
      _loadingAccount = false;
    });
    if (account != null) {
      _refreshRemoteTime();
    }
  }

  Future<void> _refreshRemoteTime() async {
    try {
      final time = await _driveSync.getRemoteBackupTime();
      if (mounted) setState(() => _remoteBackupTime = time);
    } catch (_) {
      // Ignore - user may not have granted access yet.
    }
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final account = await _driveSync.signIn();
      setState(() => _account = account);
      if (account != null) await _refreshRemoteTime();
    } catch (e) {
      _showError('Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await _driveSync.signOut();
    setState(() {
      _account = null;
      _remoteBackupTime = null;
    });
  }

  Future<void> _backupNow() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Backing up to Google Drive...';
    });
    try {
      await _driveSync.backup();
      final lastSync = await _driveSync.getLastLocalSyncTime();
      await _refreshRemoteTime();
      setState(() => _lastLocalSync = lastSync);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup completed successfully!')),
      );
    } catch (e) {
      _showError('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Drive?'),
        content: const Text(
          'This will replace all customers, bookings and deliveries on this phone with the data from your latest Google Drive backup. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Restoring from Google Drive...';
    });
    try {
      await _driveSync.restore();
      if (!mounted) return;
      await context.read<BookingProvider>().loadAllData();
      final lastSync = await _driveSync.getLastLocalSyncTime();
      setState(() => _lastLocalSync = lastSync);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore completed successfully!')),
      );
    } catch (e) {
      _showError('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Never';
    final local = time.toLocal();
    return '${local.day}/${local.month}/${local.year} at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
                  'Backup & Sync',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingAccount
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _accountCard(),
                        const SizedBox(height: 20),
                        if (_account != null) ...[
                          _statusCard(),
                          const SizedBox(height: 24),
                          if (_busy)
                            Center(
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  Text(_busyLabel ?? 'Working...', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            )
                          else ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _backupNow,
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text('Backup Now'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _restoreNow,
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: const Text('Restore from Drive'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: const BorderSide(color: AppTheme.primary),
                                  foregroundColor: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: _account == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Not signed in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  'Sign in with your Google account to back up bookings, customers and packing photos to Google Drive.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign in with Google'),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  backgroundImage: _account!.photoUrl != null ? NetworkImage(_account!.photoUrl!) : null,
                  child: _account!.photoUrl == null
                      ? Text(_account!.displayName?.isNotEmpty == true ? _account!.displayName![0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_account!.displayName ?? 'Google Account',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(_account!.email, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
                    ],
                  ),
                ),
                TextButton(onPressed: _busy ? null : _signOut, child: const Text('Sign out')),
              ],
            ),
    );
  }

  Widget _statusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sync Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          _statusRow(Icons.smartphone_rounded, 'Last backup from this phone', _formatTime(_lastLocalSync)),
          const SizedBox(height: 10),
          _statusRow(Icons.cloud_done_outlined, 'Latest backup on Drive', _formatTime(_remoteBackupTime)),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ],
          ),
        ),
      ],
    );
  }
}
