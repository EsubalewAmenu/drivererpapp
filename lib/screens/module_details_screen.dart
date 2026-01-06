import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/drive_provider.dart';
import '../providers/workspace_provider.dart';
import 'dashboard_screen.dart';

class ModuleDetailsScreen extends StatefulWidget {
  final Map<String, String> moduleInfo;

  const ModuleDetailsScreen({super.key, required this.moduleInfo});

  @override
  State<ModuleDetailsScreen> createState() => _ModuleDetailsScreenState();
}

class _ModuleDetailsScreenState extends State<ModuleDetailsScreen> {
  bool _isActivating = false;

  Future<void> _activateModule() async {
    setState(() => _isActivating = true);

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      
      if (driveProvider.driveService == null || workspaceProvider.currentWorkspace == null) {
        throw Exception("Authentication or Workspace missing");
      }

      final driveService = driveProvider.driveService!;
      final workspaceId = workspaceProvider.currentWorkspace!.id!;
      
      final moduleName = widget.moduleInfo['name']!;

      // Create the module folder in Drive
      await driveService.createWorkspace(workspaceId, moduleName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$moduleName activated successfully!')),
        );
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error activating module: $e')),
        );
        setState(() => _isActivating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(int.parse(widget.moduleInfo['color']!.replaceAll('#', '0xFF')));
    final name = widget.moduleInfo['name']!;
    final desc = widget.moduleInfo['desc']!;
    final iconName = widget.moduleInfo['icon']!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconData(iconName),
                    size: 48,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  name.toUpperCase(),
                  style: AppTheme.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: AppTheme.inter(
                    fontSize: 16,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Features / Pros
              Text(
                'KEY BENEFITS',
                style: AppTheme.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodySmall?.color,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ..._getPros(name).map((pro) => _buildFeatureItem(context, pro['title']!, pro['subtitle']!)),
              
              const Spacer(),

              // Activate Button
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: color),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'BACK',
                        style: AppTheme.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isActivating ? null : _activateModule,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isActivating 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : Text(
                            'ACTIVATE',
                            style: AppTheme.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.inter(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTheme.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getPros(String moduleName) {
    switch (moduleName) {
      case 'Inventory':
        return [
          {'title': 'Real-time Tracking', 'subtitle': 'Monitor stock levels instantly.'},
          {'title': 'Automated Alerts', 'subtitle': 'Get notified when stock is low.'},
          {'title': 'Barcode Scanning', 'subtitle': 'Quickly add items with your camera.'},
        ];
      case 'CRM':
        return [
          {'title': 'Contact Management', 'subtitle': 'Keep all customer details in one place.'},
          {'title': 'Lead Tracking', 'subtitle': 'Follow potential sales from start to finish.'},
          {'title': 'Interaction History', 'subtitle': 'See every email and call log.'},
        ];
      case 'HR':
        return [
          {'title': 'Employee Records', 'subtitle': 'Manage personal and professional details.'},
          {'title': 'Leave Management', 'subtitle': 'Track vacation and sick days easily.'},
          {'title': 'Payroll Integration', 'subtitle': 'Simplify salary processing.'},
        ];
      case 'Sales':
        return [
          {'title': 'Order Management', 'subtitle': 'Create and track orders efficiently.'},
          {'title': 'Invoice Generation', 'subtitle': 'Send professional invoices in seconds.'},
          {'title': 'Sales Analytics', 'subtitle': 'Visualize your sales performance.'},
        ];
      default:
        return [
          {'title': 'Streamlined Workflow', 'subtitle': 'Automate repetitive tasks and save time.'},
          {'title': 'Real-time Data', 'subtitle': 'Access your data instantly from anywhere.'},
          {'title': 'Secure Storage', 'subtitle': 'All data is stored safely in your Google Drive.'},
        ];
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'inventory': return Icons.inventory_2_rounded;
      case 'people': return Icons.people_alt_rounded;
      case 'shopping_cart': return Icons.shopping_cart_rounded;
      case 'local_shipping': return Icons.local_shipping_rounded;
      case 'payments': return Icons.payments_rounded;
      case 'badge': return Icons.badge_rounded;
      case 'campaign': return Icons.campaign_rounded;
      case 'receipt_long': return Icons.receipt_long_rounded;
      case 'assignment': return Icons.assignment_rounded;
      case 'account_balance': return Icons.account_balance_rounded;
      case 'analytics': return Icons.analytics_rounded;
      case 'support_agent': return Icons.support_agent_rounded;
      default: return Icons.widgets_rounded;
    }
  }
}
