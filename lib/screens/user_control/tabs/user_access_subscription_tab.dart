import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../services/billing/billing_service.dart';
import '../../../services/billing/credits_service.dart';
import '../../../providers/workspace_provider.dart';
import '../../../services/auth_service.dart';

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

  late Future<Map<String, dynamic>> _pricingFuture;
  String _selectedPlan = 'monthly'; // 'daily', 'monthly', or 'annual'
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isUpdatingAutoRenew = false;
  String? _autoRenewError;
  bool _isManualRenewing = false;
  String? _manualRenewError;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
    _loadPricing();
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

  void _loadPricing() {
    _pricingFuture = BillingService.getModulePricing(
      moduleName: widget.moduleName,
      moduleId: widget.moduleId,
    );
  }

  Future<void> _processPurchase() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final pricing = await _pricingFuture;
      final isFree = pricing['isFree'] == true;
      if (isFree) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'This module is free. No subscription is required.';
        });
        return;
      }

      final workspaceProvider =
          Provider.of<WorkspaceProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final companyId = workspaceProvider.currentCompany?.id;
      final currentEmail = authService.currentUser?.email;

      if (companyId == null) {
        throw Exception('Company not found');
      }

      if (currentEmail == null) {
        throw Exception('User not authenticated');
      }

      // Determine if this is a self-purchase or a gift (admin buying for user)
      final isGift = currentEmail != widget.email;

      // Generate a test purchase token (in production, this comes from Play Billing Library)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
        final planSuffix = _selectedPlan == 'daily'
          ? '.daily'
          : (_selectedPlan == 'annual' ? '.annual' : '.monthly');
      final purchaseToken =
          'test_token_${widget.email}_${widget.moduleId}${planSuffix}_$timestamp';

      // Get package name (would be from your app config in production)
      const packageName = 'com.datascience.apps.drivererp'; // Correct package name from google-services.json

      // Call billing service to record the subscription
      final response = await BillingService.recordPlaySubscription(
        uid: widget.email,
        packageName: packageName,
        subscriptionId: 'subscription$planSuffix', // e.g., subscription.monthly
        purchaseToken: purchaseToken,
        companyId: companyId,
        moduleId: widget.moduleId,
        moduleName: widget.moduleName,
        payerType: isGift ? 'gift' : 'self',
        payerUid: currentEmail,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _refreshStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to process subscription');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _lastRefreshed = DateTime.now();
    });
    _loadSubscriptionStatus();
    setState(() {});
  }

  Future<void> _disableAutoRenew(SubscriptionStatus status) async {
    if (status.purchaseToken == null) {
      setState(() {
        _autoRenewError = 'Missing purchase token for this subscription.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disable auto-renew?'),
          content: const Text(
            'This will stop future renewals. Access will remain active until the current period ends.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disable'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdatingAutoRenew = true;
      _autoRenewError = null;
    });

    try {
      await BillingService.disableAutoRenew(
        purchaseToken: status.purchaseToken!,
      );

      if (!mounted) return;

      _refreshStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-renew disabled.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _autoRenewError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingAutoRenew = false;
      });
    }
  }

  Future<void> _enableAutoRenew(SubscriptionStatus status) async {
    if (status.purchaseToken == null) {
      setState(() {
        _autoRenewError = 'Missing purchase token for this subscription.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable auto-renew?'),
          content: const Text(
            'Auto-renew will be turned back on for future renewals.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdatingAutoRenew = true;
      _autoRenewError = null;
    });

    try {
      await BillingService.enableAutoRenew(
        purchaseToken: status.purchaseToken!,
      );

      if (!mounted) return;

      _refreshStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-renew enabled.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _autoRenewError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingAutoRenew = false;
      });
    }
  }

  Future<void> _manualRenewSubscription(SubscriptionStatus status) async {
    if (status.purchaseToken == null) {
      setState(() {
        _manualRenewError = 'Missing purchase token for this subscription.';
      });
      return;
    }

    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final companyId = workspaceProvider.currentCompany?.id;
    if (companyId == null) {
      setState(() {
        _manualRenewError = 'Company not found.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renew now?'),
          content: const Text(
            'This will immediately deduct credits and renew this module subscription for the next period.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Renew now'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isManualRenewing = true;
      _manualRenewError = null;
    });

    try {
      await BillingService.manualRenewSubscription(
        purchaseToken: status.purchaseToken!,
        uid: widget.email,
        companyId: companyId,
        moduleId: widget.moduleId,
        moduleName: widget.moduleName,
      );

      if (!mounted) return;

      _refreshStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription renewed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualRenewError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isManualRenewing = false;
      });
    }
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
          if (status.subscriptionId != null) ...[
            _buildDetailRow(
              'Plan',
              status.subscriptionId!.contains('annual')
                  ? 'Annual Subscription'
                  : (status.subscriptionId!.contains('daily')
                      ? '1-Day Plan'
                      : 'Monthly Subscription'),
              theme.primaryColor,
              theme,
            ),
            const SizedBox(height: 12),
          ],
          // Show credits cost instead of payment type
          if (status.subscriptionId != null) ...[
            _buildDetailRow(
              'Credits Cost',
              status.subscriptionId!.contains('annual')
                  ? '999 credits / year'
                  : (status.subscriptionId!.contains('daily')
                      ? '49 credits / day'
                      : '99 credits / month'),
              const Color(0xFFFFA500), // Orange for credits
              theme,
            ),
            const SizedBox(height: 12),
          ],
          if (status.payerType != null) ...[
            _buildDetailRow(
              'Access Type',
              status.payerType == 'self' ? 'Self-purchased' : 'Gifted Access',
              theme.textTheme.bodyLarge?.color ?? Colors.grey,
              theme,
            ),
            const SizedBox(height: 12),
          ],
          if (status.renewalDate != null) ...[
            _buildDetailRow(
              status.status == 'expired' ? 'Expired On' : 'Renewal Date',
              _formatDate(status.renewalDate!),
              status.status == 'expired' ? Colors.red : (theme.textTheme.bodyLarge?.color ?? Colors.grey),
              theme,
            ),
            const SizedBox(height: 12),
          ],
          if (status.autoRenewing != null) ...[
            _buildDetailRow(
              'Auto Renewal',
              status.autoRenewing! ? 'Enabled' : 'Disabled',
              status.autoRenewing! ? Colors.green : Colors.orange,
              theme,
            ),
            const SizedBox(height: 12),
          ],
          if (status.status != 'none' &&
              status.autoRenewing != null &&
              status.purchaseToken != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTO RENEWAL',
                    style: AppTheme.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status.autoRenewing == true
                        ? 'Auto-renew is on. You can disable future renewals.'
                        : 'Auto-renew is off. Use manual renewal whenever you want to extend access.',
                    style: AppTheme.inter(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  if (status.autoRenewing == true) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUpdatingAutoRenew
                            ? null
                            : () => _disableAutoRenew(status),
                        icon: _isUpdatingAutoRenew
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.block, size: 16),
                        label: Text(
                          _isUpdatingAutoRenew
                              ? 'Disabling...'
                              : 'Disable auto-renew',
                        ),
                      ),
                    ),
                  ],
                  if (status.autoRenewing == false) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUpdatingAutoRenew
                            ? null
                            : () => _enableAutoRenew(status),
                        icon: _isUpdatingAutoRenew
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.autorenew, size: 16),
                        label: Text(
                          _isUpdatingAutoRenew
                              ? 'Enabling...'
                              : 'Enable auto-renew',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isManualRenewing
                            ? null
                            : () => _manualRenewSubscription(status),
                        icon: _isManualRenewing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bolt, size: 16),
                        label: Text(
                          _isManualRenewing ? 'Renewing...' : 'Renew now',
                        ),
                      ),
                    ),
                  ],
                  if (_autoRenewError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _autoRenewError!,
                      style: AppTheme.inter(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ],
                  if (_manualRenewError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _manualRenewError!,
                      style: AppTheme.inter(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
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
          const SizedBox(height: 20),
          FutureBuilder<Map<String, dynamic>>(
            future: _pricingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading pricing...',
                        style: AppTheme.inter(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing unavailable',
                      style: AppTheme.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(_loadPricing),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }

              final pricing = snapshot.data ?? {};
              final isFree = pricing['isFree'] == true;
              final dailyPrice = (pricing['dailyPrice'] as num?)?.toDouble() ?? 0.49;
              final monthlyPrice = (pricing['monthlyPrice'] as num?)?.toDouble() ?? 0.99;
              final annualPrice = (pricing['annualPrice'] as num?)?.toDouble() ?? 9.99;

              // Calculate credits needed for each plan
              final dailyCredits = CreditsService.calculateModuleCost(planType: 'daily', modulePrice: dailyPrice);
              final monthlyCredits = CreditsService.calculateModuleCost(planType: 'monthly', modulePrice: monthlyPrice);
              final annualCredits = CreditsService.calculateModuleCost(planType: 'annual', modulePrice: annualPrice);

              if (isFree) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This module is free. No subscription is required.',
                          style: AppTheme.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  _buildPlanOption(
                    theme: theme,
                    planId: 'daily',
                    title: '1-Day',
                    creditsNeeded: dailyCredits,
                    period: '/day',
                    isSelected: _selectedPlan == 'daily',
                  ),
                  const SizedBox(height: 12),
                  _buildPlanOption(
                    theme: theme,
                    planId: 'monthly',
                    title: 'Monthly',
                    creditsNeeded: monthlyCredits,
                    period: '/month',
                    isSelected: _selectedPlan == 'monthly',
                  ),
                  const SizedBox(height: 12),
                  _buildPlanOption(
                    theme: theme,
                    planId: 'annual',
                    title: 'Annual',
                    creditsNeeded: annualCredits,
                    period: '/year',
                    badge: 'Save 90 credits',
                    isSelected: _selectedPlan == 'annual',
                  ),
                  const SizedBox(height: 16),
                  _buildCreditBalanceInfo(theme),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTheme.inter(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Processing subscription...',
                            style: AppTheme.inter(
                              fontSize: 12,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processPurchase,
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text(
                        _isProcessing ? 'Processing...' : 'Subscribe',
                        style: AppTheme.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            theme.primaryColor.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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

  Widget _buildPlanOption({
    required ThemeData theme,
    required String planId,
    required String title,
    required int creditsNeeded,
    required String period,
    required bool isSelected,
    String? badge,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : () => setState(() => _selectedPlan = planId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withValues(alpha: 0.1)
              : theme.cardTheme.color,
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ignore: deprecated_member_use
                Radio<String>(
                  value: planId,
                  // ignore: deprecated_member_use
                  groupValue: _selectedPlan,
                  // ignore: deprecated_member_use
                  onChanged: _isProcessing ? null : (value) {
                    if (value != null) {
                      setState(() => _selectedPlan = value);
                    }
                  },
                  activeColor: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: AppTheme.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$creditsNeeded',
                  style: AppTheme.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'credits $period',
                  style: AppTheme.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditBalanceInfo(ThemeData theme) {
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final companyId = workspaceProvider.currentCompany?.id;

    if (companyId == null) {
      return SizedBox.shrink();
    }

    return FutureBuilder<WorkspaceCredits>(
      future: CreditsService.getWorkspaceCredits(companyId: companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ),
            ),
          );
        }

        final credits = snapshot.data;
        if (credits == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_outlined, color: Colors.orange, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No credits available. Buy credits from the Credits page to subscribe.',
                    style: AppTheme.inter(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${credits.balance.toInt()} credits available',
                      style: AppTheme.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    Text(
                      'Manage credits in the Credits & Billing page',
                      style: AppTheme.inter(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
