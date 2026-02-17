import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../services/billing/billing_service.dart';
import '../../../providers/workspace_provider.dart';

class UserAccessSubscriptionTab extends StatefulWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;
  final int rowIndex;

  const UserAccessSubscriptionTab({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
    required this.rowIndex,
  });

  @override
  State<UserAccessSubscriptionTab> createState() => _UserAccessSubscriptionTabState();
}

class _UserAccessSubscriptionTabState extends State<UserAccessSubscriptionTab> {
  late Future<SubscriptionStatus> _statusFuture;
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  void _loadSubscriptionStatus() {
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final companyId = workspaceProvider.currentCompany?.id;

    if (companyId == null) {
      _statusFuture = Future.error('Company not found');
    } else {
      _statusFuture = BillingService.getEntitlementStatus(
        uid: widget.email,
        companyId: companyId,
        moduleId: widget.moduleId,
      );
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _lastRefreshed = DateTime.now();
    });
    _loadSubscriptionStatus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshStatus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<SubscriptionStatus>(
            future: _statusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading subscription status...',
                          style: AppTheme.inter(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading subscription',
                          style: AppTheme.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: AppTheme.inter(
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _refreshStatus,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final status = snapshot.data!;

              return Column(
                children: [
                  _buildStatusCard(status, theme),
                  const SizedBox(height: 20),
                  if (status.status != 'none')
                    _buildDetailsCard(status, theme)
                  else
                    _buildNoSubscriptionCard(theme),
                  const SizedBox(height: 20),
                  _buildRefreshInfo(theme),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(SubscriptionStatus status, ThemeData theme) {
    final statusColor = _getStatusColor(status, theme);
    final statusLabel = _getStatusLabel(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            statusIcon,
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            statusLabel,
            style: AppTheme.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${widget.moduleName}',
            style: AppTheme.inter(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          if (status.status != 'none' && status.daysUntilRenewal != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Renews in ${status.daysUntilRenewal} day${status.daysUntilRenewal != 1 ? 's' : ''}',
                style: AppTheme.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard(SubscriptionStatus status, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUBSCRIPTION DETAILS',
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Status',
            _getStatusLabel(status),
            _getStatusColor(status, theme),
            theme,
          ),
          const SizedBox(height: 12),
          if (status.payerType != null)
            _buildDetailRow(
              'Payment Type',
              status.payerType == 'self' ? 'Self-paid' : 'Gift',
              theme.textTheme.bodyLarge?.color ?? Colors.grey,
              theme,
            ),
          if (status.payerType != null) const SizedBox(height: 12),
          if (status.renewalDate != null)
            _buildDetailRow(
              'Renewal Date',
              _formatDate(status.renewalDate!),
              theme.textTheme.bodyLarge?.color ?? Colors.grey,
              theme,
            ),
          if (status.renewalDate != null) const SizedBox(height: 12),
          if (status.autoRenewing != null)
            _buildDetailRow(
              'Auto Renewal',
              status.autoRenewing! ? 'Enabled' : 'Disabled',
              status.autoRenewing! ? Colors.green : Colors.orange,
              theme,
            ),
          if (status.autoRenewing != null) const SizedBox(height: 12),
          if (status.source != null)
            _buildDetailRow(
              'Platform',
              status.source == 'google' ? 'Google Play' : 'Apple App Store',
              theme.primaryColor,
              theme,
            ),
        ],
      ),
    );
  }

  Widget _buildNoSubscriptionCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No subscription found',
            style: AppTheme.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This user does not have an active subscription for this module.',
            textAlign: TextAlign.center,
            style: AppTheme.inter(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Subscriptions are managed through the app\'s billing system.',
            textAlign: TextAlign.center,
            style: AppTheme.inter(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color valueColor,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.inter(
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: AppTheme.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            Icons.refresh,
            size: 14,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _lastRefreshed != null
                  ? 'Last refreshed: ${_formatTime(_lastRefreshed!)}'
                  : 'Pull to refresh',
              style: AppTheme.inter(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SubscriptionStatus status, ThemeData theme) {
    switch (status.status) {
      case 'active':
        return Colors.green;
      case 'grace':
        return Colors.orange;
      case 'expired':
      case 'canceled':
        return Colors.red;
      default:
        return theme.disabledColor;
    }
  }

  IconData _getStatusIcon(SubscriptionStatus status) {
    switch (status.status) {
      case 'active':
        return Icons.check_circle;
      case 'grace':
        return Icons.warning_amber;
      case 'expired':
      case 'canceled':
        return Icons.cancel;
      case 'none':
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(SubscriptionStatus status) {
    switch (status.status) {
      case 'active':
        return 'Active';
      case 'grace':
        return 'Grace Period';
      case 'expired':
        return 'Expired';
      case 'canceled':
        return 'Canceled';
      case 'none':
        return 'No Subscription';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${_pad(time.minute)}';
  }

  String _pad(int number) => number.toString().padLeft(2, '0');
}
