import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/app_theme.dart';
import '../../services/billing/credits_service.dart';
import '../../providers/workspace_provider.dart';

class CreditsTopupScreen extends StatefulWidget {
  const CreditsTopupScreen({super.key});

  @override
  State<CreditsTopupScreen> createState() => _CreditsTopupScreenState();
}

class _CreditsTopupScreenState extends State<CreditsTopupScreen> {
  static const Map<int, String> _androidTopupProductIds = {
    100: 'credits_100',
    500: 'credits_500',
    1000: 'credits_1000',
    5000: 'credits_5000',
    10000: 'credits_10000',
  };

  static const Map<int, String> _iosTopupProductIds = {
    100: 'credits_100',
    500: 'credits_500',
    1000: 'credits_1000',
    5000: 'credits_5000',
    10000: 'credits_10000',
  };

  Map<int, String> get _platformTopupProductIds =>
      Platform.isIOS ? _iosTopupProductIds : _androidTopupProductIds;

  late Future<WorkspaceCredits> _creditsFuture;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Set<String> _processedPurchaseTokens = <String>{};
  List<ProductDetails> _availableProducts = const [];

  int _selectedTopupAmount = 100; // Default 100 credits
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;

  // Predefined topup options
  final List<int> topupOptions = [100, 500, 1000, 5000, 10000]; // credits

  @override
  void initState() {
    super.initState();
    _loadCredits();
    _initStorePurchaseFlow();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  void _loadCredits() {
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final companyId = workspaceProvider.currentCompany?.id;

    if (companyId != null) {
      _creditsFuture = CreditsService.getWorkspaceCredits(companyId: companyId);
    }
  }

  Future<void> _initStorePurchaseFlow() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Store is not available on this device.';
      });
      return;
    }

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _errorMessage = error.toString();
        });
      },
    );

    ProductDetailsResponse response = await _queryProductDetailsWithRetry(
      _platformTopupProductIds.values.toSet(),
    );

    if (!mounted) return;

    if (response.error != null) {
      setState(() {
        _errorMessage = Platform.isIOS
            ? 'Unable to connect to Apple Store right now. Please make sure your iPhone is signed in with an Apple ID and try again.'
            : response.error!.message;
      });
      return;
    }

    if (response.productDetails.isEmpty && Platform.isAndroid) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      response = await _inAppPurchase.queryProductDetails(
        _platformTopupProductIds.values.toSet(),
      );

      if (!mounted) return;
    }

    if (response.productDetails.isEmpty) {
      final missingIds = response.notFoundIDs.isNotEmpty
          ? response.notFoundIDs.join(', ')
          : _platformTopupProductIds.values.join(', ');

      setState(() {
        _errorMessage = Platform.isIOS
            ? 'No Apple top-up products found. Verify product IDs in App Store Connect.'
            : 'No top-up products found in Google Play. Missing IDs: $missingIds. Install this build from Google Play internal testing with the tester account and make sure those products are Active in Play Console.';
      });
      return;
    }

    setState(() {
      _availableProducts = response.productDetails;
    });
  }

  Future<ProductDetailsResponse> _queryProductDetailsWithRetry(
    Set<String> productIds,
  ) async {
    ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(productIds);

    final shouldRetry = Platform.isIOS &&
        response.error != null &&
        response.error!.message.contains(
          'StoreKit: Failed to get response from platform.',
        );

    if (shouldRetry) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      response = await _inAppPurchase.queryProductDetails(productIds);
    }

    return response;
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (!_platformTopupProductIds.values.contains(purchaseDetails.productID)) {
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (!mounted) return;
        setState(() {
          _isProcessing = true;
        });
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _errorMessage = purchaseDetails.error?.message ?? 'Purchase failed';
        });
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _handleSuccessfulPurchase(purchaseDetails);
      } else {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    final purchaseToken =
        purchaseDetails.verificationData.serverVerificationData.isNotEmpty
            ? purchaseDetails.verificationData.serverVerificationData
            : (purchaseDetails.purchaseID ?? '');

    if (purchaseToken.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Purchase token missing from store response.';
      });
      return;
    }

    if (_processedPurchaseTokens.contains(purchaseToken)) {
      return;
    }

    _processedPurchaseTokens.add(purchaseToken);

    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final companyId = workspaceProvider.currentCompany?.id;
    final creditsAmount = _platformTopupProductIds.entries
        .firstWhere(
          (entry) => entry.value == purchaseDetails.productID,
          orElse: () => const MapEntry(0, ''),
        )
        .key;

    if (companyId == null || creditsAmount <= 0) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Unable to map purchased product to credits.';
      });
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      final updatedCredits = await CreditsService.topupCredits(
        companyId: companyId,
        credits: creditsAmount,
        platform: Platform.isAndroid ? 'google_play' : 'apple',
        purchaseId: purchaseToken,
        productId: purchaseDetails.productID,
        packageName: packageInfo.packageName,
      );

      if (!mounted) return;

      setState(() {
        _creditsFuture = Future.value(updatedCredits);
        _successMessage = 'Successfully purchased $creditsAmount credits!';
        _errorMessage = null;
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credits purchased successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _topupCredits() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      setState(() {
        _errorMessage = 'In-app purchase is only available on Android/iOS.';
      });
      return;
    }

    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final companyId = workspaceProvider.currentCompany?.id;

    if (companyId == null) {
      setState(() {
        _errorMessage = 'Company not found';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final productId = _platformTopupProductIds[_selectedTopupAmount];
      if (productId == null) {
        throw Exception('No product mapping found for $_selectedTopupAmount credits.');
      }

      final matchingProduct = _availableProducts
          .where((product) => product.id == productId)
          .toList();

      if (matchingProduct.isEmpty) {
        throw Exception(
          'Product "$productId" is not available from store. '
          'Make sure it exists and is active in Play Console.',
        );
      }

      final purchaseParam = PurchaseParam(productDetails: matchingProduct.first);

      final purchaseStarted = Platform.isAndroid
          ? await _inAppPurchase.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: true,
            )
          : await _inAppPurchase.buyNonConsumable(
              purchaseParam: purchaseParam,
            );

      if (!purchaseStarted) {
        throw Exception('Failed to start store purchase flow.');
      }

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showAutoTopupDialog(WorkspaceCredits currentCredits) async {
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final companyId = workspaceProvider.currentCompany?.id;

    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company not found')),
      );
      return;
    }

    int selectedAmount = currentCredits.autoTopupAmount ?? 1000;
    bool enableAutoTopup = currentCredits.autoTopupEnabled;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Text(
              'Auto-Topup Configuration',
              style: AppTheme.inter(fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatically add credits on the 1st of each month.',
                  style: AppTheme.inter(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Enable Auto-Topup', style: AppTheme.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: enableAutoTopup,
                  onChanged: (value) {
                    setDialogState(() {
                      enableAutoTopup = value;
                    });
                  },
                ),
                if (enableAutoTopup) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Monthly Amount',
                    style: AppTheme.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [100, 500, 1000, 5000, 10000].map((amount) {
                      final isSelected = selectedAmount == amount;
                      return ChoiceChip(
                        label: Text(
                          '$amount',
                          style: AppTheme.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              selectedAmount = amount;
                            });
                          }
                        },
                        selectedColor: theme.primaryColor,
                        backgroundColor: theme.cardTheme.color,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monthly cost: ${CreditsService.creditsToUsd(selectedAmount)}',
                    style: AppTheme.inter(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: AppTheme.inter()),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'enabled': enableAutoTopup,
                    'amount': selectedAmount,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('Save', style: AppTheme.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    // Save the auto-topup configuration
    try {
      final updatedCredits = await CreditsService.setAutoTopup(
        companyId: companyId,
        enabled: result['enabled'] as bool,
        amount: result['amount'] as int?,
      );

      if (!mounted) return;

      setState(() {
        _creditsFuture = Future.value(updatedCredits);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['enabled'] 
                ? 'Auto-topup enabled successfully!' 
                : 'Auto-topup disabled',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('CREDITS & BILLING', style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: theme.textTheme.titleLarge?.color)),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<WorkspaceCredits>(
              future: _creditsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorState(theme, snapshot.error);
                }

                final credits = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCreditsDisplay(credits, theme),
                    const SizedBox(height: 32),
                    _buildPricingInfo(theme),
                    const SizedBox(height: 32),
                    _buildTopupSection(credits, theme),
                    const SizedBox(height: 32),
                    _buildAutoTopupSection(credits, theme),
                    const SizedBox(height: 32),
                    _buildHistorySection(credits, theme),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Object? error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Error loading credits',
            style: AppTheme.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: AppTheme.inter(
              fontSize: 12,
              color: Colors.red.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _loadCredits()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsDisplay(WorkspaceCredits credits, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Credits',
            style: AppTheme.inter(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${credits.balance.toInt()}',
                style: AppTheme.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'credits',
                style: AppTheme.inter(
                  fontSize: 16,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '≈ ${CreditsService.creditsToUsd(credits.balance.toInt())}',
            style: AppTheme.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRICING',
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 Credit',
                style: AppTheme.inter(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              Text(
                '\$0.01',
                style: AppTheme.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '100 Credits',
                style: AppTheme.inter(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              Text(
                '\$1.00',
                style: AppTheme.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Credits are used to maintain module subscriptions. Each module subscription costs credits equal to its monthly price.',
            style: AppTheme.inter(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopupSection(WorkspaceCredits credits, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUY CREDITS',
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: topupOptions.map((amount) {
            final isSelected = _selectedTopupAmount == amount;
            return GestureDetector(
              onTap: () => setState(() => _selectedTopupAmount = amount),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$amount',
                      style: AppTheme.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      CreditsService.creditsToUsd(amount),
                      style: AppTheme.inter(
                        fontSize: 12,
                        color: isSelected
                            ? theme.primaryColor
                            : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Text(
              _successMessage!,
              style: AppTheme.inter(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _topupCredits,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outlined),
            label: Text(
              _isProcessing
                  ? 'Processing...'
                  : Platform.isIOS
                      ? 'Purchase $_selectedTopupAmount credits with Apple'
                      : 'Purchase $_selectedTopupAmount credits',
              style: AppTheme.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: theme.primaryColor.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoTopupSection(WorkspaceCredits credits, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AUTO-TOPUP',
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Automatically add credits on the 1st of each month to avoid subscription interruptions.',
            style: AppTheme.inter(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          if (credits.autoTopupEnabled && credits.autoTopupAmount != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-topup Enabled',
                          style: AppTheme.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '${credits.autoTopupAmount} credits monthly (${CreditsService.creditsToUsd(credits.autoTopupAmount!)})',
                          style: AppTheme.inter(
                            fontSize: 11,
                            color: Colors.green.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAutoTopupDialog(credits),
              icon: const Icon(Icons.settings),
              label: Text(
                credits.autoTopupEnabled ? 'Modify auto-topup' : 'Enable auto-topup',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(WorkspaceCredits credits, ThemeData theme) {
    if (credits.transactionHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRANSACTION HISTORY',
              style: AppTheme.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: AppTheme.inter(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSACTION HISTORY',
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ...credits.transactionHistory.take(20).map((transaction) {
            final isDeduction = transaction.isDeduction;
            final isAutoTopup = transaction.type == 'auto-topup';
            final renewalSourceLabel = transaction.renewalSource == 'manual'
              ? 'Manual renew'
              : transaction.renewalSource == 'auto'
                ? 'Auto renew'
                : transaction.renewalSource == 'subscription'
                  ? 'New subscription'
                  : null;
            final iconData = isDeduction 
                ? Icons.remove_circle_outline 
                : isAutoTopup 
                    ? Icons.schedule 
                    : Icons.add_circle_outline;
            final color = isDeduction ? Colors.red : Colors.green;
            final typeLabel = transaction.type == 'subscription' 
                ? 'Module subscription' 
                : transaction.type == 'topup' 
                    ? 'Credit topup'
                    : transaction.type == 'auto-topup'
                        ? 'Auto-topup (Monthly)'
                        : transaction.type.toUpperCase();
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDeduction 
                    ? Colors.red.withValues(alpha: 0.05)
                    : Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDeduction 
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(iconData, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: AppTheme.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        if (transaction.moduleName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Module: ${transaction.moduleName}',
                            style: AppTheme.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        if (transaction.userEmail != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'For: ${transaction.userEmail}',
                            style: AppTheme.inter(
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                        if (transaction.type == 'subscription' && renewalSourceLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Source: $renewalSourceLabel',
                            style: AppTheme.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        if (transaction.platform != null && transaction.type == 'topup') ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: transaction.platform == 'google_play'
                                  ? const Color(0xFF4285F4).withValues(alpha: 0.15)
                                  : const Color(0xFF555555).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              transaction.platform == 'google_play' ? '🔵 Google Play' : '🍎 Apple',
                              style: AppTheme.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: transaction.platform == 'google_play'
                                    ? const Color(0xFF4285F4)
                                    : const Color(0xFF555555),
                              ),
                            ),
                          ),
                        ],
                        if (transaction.purchaseId != null && transaction.type == 'topup') ...[
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${_truncatePurchaseId(transaction.purchaseId!)}',
                            style: AppTheme.inter(
                              fontSize: 9,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}-${transaction.date.day.toString().padLeft(2, '0')} ${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}',
                          style: AppTheme.inter(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isDeduction ? '' : '+'}${transaction.credits}',
                        style: AppTheme.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        CreditsService.creditsToUsd(transaction.credits.abs()),
                        style: AppTheme.inter(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Truncate purchase ID for display (show first 10 and last 10 chars)
  String _truncatePurchaseId(String purchaseId) {
    if (purchaseId.length <= 20) {
      return purchaseId;
    }
    return '${purchaseId.substring(0, 10)}...${purchaseId.substring(purchaseId.length - 10)}';
  }
}
