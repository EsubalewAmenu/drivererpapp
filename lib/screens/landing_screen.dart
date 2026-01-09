import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../services/auth_service.dart';
import '../providers/workspace_provider.dart';
import '../providers/drive_provider.dart';
import '../theme/app_theme.dart';
import 'system_scanning_screen.dart';
import 'dashboard_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Attempt silent sign-in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSilentSignIn();
    });
  }

  Future<void> _checkSilentSignIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signInSilently();
    
    if (authService.isAuthenticated && mounted) {
      // Attempt to auto-restore workspace
      final lastWorkspaceId = await WorkspaceProvider.getLastWorkspaceId();
      if (lastWorkspaceId != null) {
        try {
          final driveProvider = Provider.of<DriveProvider>(context, listen: false);
          
          // Ensure client is synced if proxy update hasn't propagated yet (edge case)
          if (driveProvider.driveService == null && authService.authClient != null) {
             driveProvider.updateClient(authService.authClient);
          }

          if (driveProvider.driveService != null) {
            final success = await Provider.of<WorkspaceProvider>(context, listen: false)
                .restorePreviousSession();
            
            if (success && mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('Error restoring workspace: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SystemScanningScreen()),
        );
        return;
      }
    }

    // If not authenticated or checks failed, show the login UI
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine responsive layout or other factors if needed
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Logo / Brand
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storage_rounded,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'DRIVE ERP',
                textAlign: TextAlign.center,
                style: AppTheme.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: theme.textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your Business. Your Drive. Your Data.',
                textAlign: TextAlign.center,
                style: AppTheme.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              
              const Spacer(flex: 1),
              
              // Trust Indicators / No-DB Architecture
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    _buildTrustItem(
                      context,
                      Icons.lock_outline_rounded,
                      'No External Database',
                      'Data lives in your Google Drive',
                    ),
                    const SizedBox(height: 16),
                    _buildTrustItem(
                      context,
                      Icons.cloud_off_rounded,
                      'Sovereign Ownership',
                      'You own the raw data files',
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Google Sign In Button
              if (_isLoading)
                 Container(
                   height: 56, // Match button height roughly
                   alignment: Alignment.center,
                   child: const SizedBox(
                     width: 24, 
                     height: 24,
                     child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2.5),
                   ),
                 )
              else
                FilledButton.icon(
                  onPressed: () => _handleGoogleSignIn(context),
                  icon: const Icon(Icons.login_rounded), // Placeholder for Google Icon
                  label: Text(
                    'Continue with Google',
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
                    elevation: 0,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'By continuing, you agree to our Terms & Privacy Policy',
                textAlign: TextAlign.center,
                style: AppTheme.inter(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustItem(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                subtitle,
                style: AppTheme.inter(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color, // Consistent with secondary text
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final localNavigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signIn();

      if (context.mounted) {
        rootNavigator.pop(); // Close loading dialog
        if (authService.isAuthenticated) {
          localNavigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const SystemScanningScreen()),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        rootNavigator.pop(); // Close loading dialog
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    }
  }
}
