import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'system_scanning_screen.dart';

class ConnectGoogleDriveScreen extends StatefulWidget {
  const ConnectGoogleDriveScreen({super.key});

  @override
  State<ConnectGoogleDriveScreen> createState() => _ConnectGoogleDriveScreenState();
}

class _ConnectGoogleDriveScreenState extends State<ConnectGoogleDriveScreen> {
  bool _isConnecting = false;

  Future<void> _connectGoogleDrive() async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final localNavigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isConnecting = true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signIn();

      if (!mounted) {
        return;
      }

      rootNavigator.pop();

      if (authService.isAuthenticated) {
        localNavigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SystemScanningScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        rootNavigator.pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Google Drive connection failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'CONNECT GOOGLE DRIVE',
          style: AppTheme.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.cloud_sync_rounded,
                size: 56,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'One more step',
                textAlign: TextAlign.center,
                style: AppTheme.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'DriveERP stores your ERP data in your Google Drive.\nConnect Google to continue.',
                textAlign: TextAlign.center,
                style: AppTheme.inter(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _isConnecting ? null : _connectGoogleDrive,
                icon: const Icon(Icons.login_rounded),
                label: Text(
                  _isConnecting ? 'Connecting...' : 'Connect Google Drive',
                  style: AppTheme.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
