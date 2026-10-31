import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:provider/provider.dart';
import '../providers/erp_controller.dart';
import '../services/backend/backend_session.dart';

class NativeBillingScreen extends StatefulWidget {
  const NativeBillingScreen({super.key});
  @override
  State<NativeBillingScreen> createState() => _NativeBillingScreenState();
}

class _NativeBillingScreenState extends State<NativeBillingScreen> {
  Map<String, dynamic>? credits;
  String? error;
  bool busy = false;
  List<ProductDetails> products = [];
  StreamSubscription<List<PurchaseDetails>>? listener;
  final amounts = const {
    'credits_100': 100,
    'credits_500': 500,
    'credits_1000': 1000,
    'credits_5000': 5000,
    'credits_10000': 10000,
  };
  @override
  void initState() {
    super.initState();
    listener = InAppPurchase.instance.purchaseStream.listen(
      _purchases,
      onError: (Object e) {
        if (mounted) setState(() => error = e.toString());
      },
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final c = context.read<ErpController>();
      final result = await c.api.billing('getWorkspaceCredits', {
        'companyId': c.company!.id,
      });
      if (mounted) setState(() => credits = result);
      if (await InAppPurchase.instance.isAvailable()) {
        final result = await InAppPurchase.instance.queryProductDetails(
          amounts.keys.toSet(),
        );
        if (mounted) setState(() => products = result.productDetails);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _purchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) {
        if (mounted) setState(() => busy = true);
        continue;
      }
      try {
        if (p.status == PurchaseStatus.error) {
          throw StateError(p.error?.message ?? 'Purchase failed');
        }
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          final c = context.read<ErpController>();
          await c.api.billing('topupWorkspaceCredits', {
            'companyId': c.company!.id,
            'productId': p.productID,
            'credits': amounts[p.productID],
            'platform': Platform.isIOS ? 'apple' : 'google_play',
            'purchaseId': p.verificationData.serverVerificationData,
          });
          if (Platform.isAndroid) {
            await InAppPurchase.instance
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
                .consumePurchase(p);
          }
          if (p.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(p);
          }
          await _load();
        }
      } catch (e) {
        if (mounted) setState(() => error = e.toString());
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  Future<void> _subscription(
    String action,
    String module, {
    String? plan,
    String? email,
  }) async {
    try {
      final c = context.read<ErpController>();
      final result = await c.api.billing(action, {
        'companyId': c.company!.id,
        'moduleId': module,
        'uid': email ?? BackendSession.email,
        if (plan != null) 'subscriptionId': plan,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result['status']} · ${result['expiryTime'] ?? ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _plan(String module) async {
    String plan = 'subscription.monthly';
    var email = BackendSession.email;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Module subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: email,
                onChanged: (v) => email = v,
                decoration: const InputDecoration(
                  labelText: 'Member email (yourself or a gift)',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: plan,
                items: const [
                  DropdownMenuItem(
                    value: 'subscription.daily',
                    child: Text('Daily · 49 credits'),
                  ),
                  DropdownMenuItem(
                    value: 'subscription.monthly',
                    child: Text('Monthly · 99 credits'),
                  ),
                  DropdownMenuItem(
                    value: 'subscription.annual',
                    child: Text('Annual · 999 credits'),
                  ),
                ],
                onChanged: (v) => set(() => plan = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pay with credits'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _subscription(
        'recordPlaySubscription',
        module,
        plan: plan,
        email: email.trim(),
      );
    }
  }

  @override
  void dispose() {
    listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ErpController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Credits and subscriptions')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!),
                ),
              ),
            Text(
              '${credits?['balance'] ?? '…'} credits',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text(
              'Credits and subscriptions are stored with your company on this server.',
            ),
            if (busy) const LinearProgressIndicator(),
            for (final p in products)
              ListTile(
                title: Text(p.title),
                subtitle: Text(p.description),
                trailing: FilledButton(
                  onPressed: busy
                      ? null
                      : () => InAppPurchase.instance.buyConsumable(
                          purchaseParam: PurchaseParam(productDetails: p),
                          autoConsume: false,
                        ),
                  child: Text(p.price),
                ),
              ),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Credit purchases require store products and server receipt verification credentials.',
                ),
              ),
            TextButton(
              onPressed: () => InAppPurchase.instance.restorePurchases(),
              child: const Text('Restore purchases'),
            ),
            const Divider(),
            for (final module in c.modules)
              ListTile(
                title: Text(module.name),
                subtitle: const Text('Subscription, renewal, or member gift'),
                onTap: () => _plan(module.id),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _subscription(action, module.id),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'getEntitlementStatus',
                      child: Text('Check status'),
                    ),
                    PopupMenuItem(
                      value: 'manualRenewSubscription',
                      child: Text('Renew with credits'),
                    ),
                    PopupMenuItem(
                      value: 'disablePlayAutoRenew',
                      child: Text('Disable renewal'),
                    ),
                    PopupMenuItem(
                      value: 'enablePlayAutoRenew',
                      child: Text('Enable renewal'),
                    ),
                  ],
                ),
              ),
            const Divider(),
            const Text('Transaction history'),
            for (final t in (credits?['transactionHistory'] as List? ?? []))
              ListTile(
                title: Text('${t['type']} · ${t['credits']} credits'),
                subtitle: Text('${t['date']}'),
              ),
          ],
        ),
      ),
    );
  }
}
