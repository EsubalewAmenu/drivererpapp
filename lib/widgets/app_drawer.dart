import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../screens/settings_screen.dart';
import '../screens/system_scanning_screen.dart';
import '../screens/landing_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surfaceColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildWorkspaceSwitcher(context),
            const SizedBox(height: 32),
            _buildNavigationLinks(context),
            const Spacer(),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            'DRIVE ERP',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSwitcher(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: () {
            // Navigate to system scanning to refresh workspaces
             Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SystemScanningScreen()),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blueGrey,
                child: Text('A', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Acme Corp', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textColor)),
                    Text('Switch Workspace', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.secondaryTextColor)),
                  ],
                ),
              ),
              const Icon(Icons.swap_horiz_rounded, color: AppTheme.secondaryTextColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationLinks(BuildContext context) {
    return Column(
      children: [
        _buildNavItem(context, Icons.dashboard_rounded, 'Dashboard', onTap: () {
          Navigator.pop(context); // Close drawer
        }),
        _buildNavItem(context, Icons.settings_rounded, 'Settings', onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        }),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.secondaryTextColor),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      horizontalTitleGap: 0,
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Divider(color: Colors.white10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E)), // Rose color
            title: Text(
              'Log Out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF43F5E),
              ),
            ),
            onTap: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
