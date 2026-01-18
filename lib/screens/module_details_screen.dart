import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/schema_service.dart';
import '../theme/app_theme.dart';
import '../providers/drive_provider.dart';
import '../providers/schema_provider.dart';
import '../models/schema_models.dart';
import '../providers/workspace_provider.dart';
import 'dashboard_screen.dart';

class ModuleDetailsScreen extends StatefulWidget {
  final Map<String, String> moduleInfo;
  final String? hostModuleId;

  const ModuleDetailsScreen({super.key, required this.moduleInfo, this.hostModuleId});

  @override
  State<ModuleDetailsScreen> createState() => _ModuleDetailsScreenState();
}

class _ModuleDetailsScreenState extends State<ModuleDetailsScreen> {
  bool _isActivating = false;
  Map<String, dynamic>? _moduleJson;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadModuleConfig();
  }

  Future<void> _loadModuleConfig() async {
    try {
      final key = (widget.moduleInfo['id'] ?? widget.moduleInfo['name'])!.toString().toLowerCase().trim();
      final jsonString = await SchemaService.tryLoadModuleAsset(key);
      if (jsonString != null) {
        if (mounted) {
          setState(() {
            _moduleJson = jsonDecode(jsonString);
            _errorMessage = null;
          });
        }
      } else {
        throw Exception('Module asset not found for key: $key');
      }
    } catch (e) {
      debugPrint('Error loading module config in details: $e');
      if (mounted && widget.moduleInfo['name'] == 'HR') {
        setState(() {
          _errorMessage = "Error Loading Module";
        });
      }
    }
  }

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
      final assetKey = (widget.moduleInfo['id'] ?? widget.moduleInfo['name'])!.toString().toLowerCase().trim();

      // Create the module folder in Drive
      final _createdModuleRes = (driveService as dynamic).createWorkspace(workspaceId, moduleName);
      dynamic createdModule;
      if (_createdModuleRes is Future) {
        createdModule = await _createdModuleRes;
      } else {
        createdModule = _createdModuleRes;
      }
      if (createdModule == null || createdModule.id == null) {
        throw Exception('Failed to create module folder');
      }
      final moduleFolderId = createdModule.id!;

      // Auto-seed Initial Data
      if (_moduleJson != null && _moduleJson!['tabs'] != null) {
        final tabs = _moduleJson!['tabs'] as List;
        for (var tab in tabs) {
          if (tab is Map && tab['initial_data'] != null) {
            final initialData = tab['initial_data'] as List;
            final tabId = tab['id'];

            for (var record in initialData) {
              if (record is Map<String, dynamic>) {
                try {
                  final res = (driveService as dynamic).saveRecord(
                    moduleFolderId,
                    moduleName,
                    tabId,
                    record,
                  );
                  if (res is Future) await res;
                } catch (e) {
                  debugPrint('Error seeding record for $tabId: $e');
                }
              }
            }
            // After seeding, capture the created spreadsheet id and attach to the tab
            try {
              final _existingIdRes = (driveService as dynamic).getFileId(moduleFolderId, tabId);
              dynamic existingId;
              if (_existingIdRes is Future) {
                existingId = await _existingIdRes;
              } else {
                existingId = _existingIdRes;
              }
              if (existingId != null) {
                tab['fileId'] = existingId;
              }
            } catch (e) {
              debugPrint('Error fetching fileId for $tabId after seeding: $e');
            }
          }
        }
      }

      // Create config folder and default config file now (so module has config immediately)
      try {
        if (_moduleJson != null) {
          final _configFolderRes = (driveService as dynamic).getOrCreateSubFolder(moduleFolderId, 'config');
          dynamic configFolderId;
          if (_configFolderRes is Future) {
            configFolderId = await _configFolderRes;
          } else {
            configFolderId = _configFolderRes;
          }
          if (configFolderId == null) {
            throw Exception('Failed to ensure config folder');
          }
          final authService = Provider.of<AuthService>(context, listen: false);
          final userEmail = authService.currentUser?.email;
          final configFileName = userEmail != null && userEmail.isNotEmpty ? '${userEmail}_config' : 'config';
          try {
            // Create module config on Drive and capture its fileId if returned
            dynamic _createCfgRes = (driveService as dynamic).createModuleConfig(configFolderId, configFileName, _moduleJson!);
            dynamic createdCfgId;
            if (_createCfgRes is Future) {
              createdCfgId = await _createCfgRes;
            } else {
              createdCfgId = _createCfgRes;
            }

            // Cache the created module JSON locally under the new module folder id
            try {
              final provider = Provider.of<SchemaProvider>(context, listen: false);
              // Cache under the Drive folder id so lookups by folder find it
              await provider.service.cacheConfig(moduleFolderId, _moduleJson!);
              // Also cache under the authoritative asset key (short key) so
              // any code that looks up by the module asset id/name sees it immediately
              try {
                await provider.service.cacheConfig(assetKey, _moduleJson!);
              } catch (_) {}

              // Also create an in-memory ModuleSchema so UI can pick it up immediately
              final settingsRaw = _moduleJson!['settings'];
              final settingsMap = <String, SettingItem>{};
              if (settingsRaw != null && settingsRaw is Map<String, dynamic>) {
                settingsRaw.forEach((k, v) {
                  try {
                    settingsMap[k] = SettingItem.fromJson(Map<String, dynamic>.from(v as Map));
                  } catch (_) {}
                });
              }

              final dashboardJson = _moduleJson!['dashboard'] != null ? Map<String, dynamic>.from(_moduleJson!['dashboard'] as Map) : null;
              final dashboard = (dashboardJson != null && dashboardJson['cards'] != null)
                  ? DashboardConfig.fromJson(dashboardJson)
                  : DashboardConfig(cards: []);

              final tabsRaw = _moduleJson!['tabs'];
              final tabsList = tabsRaw != null ? List<dynamic>.from(tabsRaw as List) : [];
              final tabs = tabsList.map((t) {
                try {
                  return TabConfig.fromJson(Map<String, dynamic>.from(t as Map));
                } catch (_) {
                  return TabConfig(id: 'err', label: 'Error Tab', columns: []);
                }
              }).toList();

              final moduleSchema = ModuleSchema(
                id: moduleFolderId,
                name: settingsMap['name']?.value?.toString() ?? moduleName,
                icon: settingsMap['icon']?.value?.toString() ?? '',
                primaryColor: settingsMap['primaryColor']?.value?.toString() ?? '#2196F3',
                version: settingsMap['version']?.value?.toString() ?? '1.0',
                settings: settingsMap,
                dashboard: dashboard,
                tabs: tabs,
              );

              // After activation, clear local cached configs and in-memory
              // entries for the extension (short key + folder id) and the
              // host module so subsequent opens will fetch fresh data from
              // Drive and avoid stale prefixed ids.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  if (!mounted) return;
                  try {
                    await provider.service.removeCachedConfig(assetKey);
                  } catch (_) {}
                  try {
                    await provider.service.removeCachedConfig(moduleFolderId);
                  } catch (_) {}
                  if (widget.hostModuleId != null && widget.hostModuleId!.isNotEmpty) {
                    try {
                      await provider.service.removeCachedConfig(widget.hostModuleId!);
                    } catch (_) {}
                  }

                  // Clear in-memory entries so UI will re-resolve from Drive
                  try {
                    provider.updateMemoryCache(moduleFolderId, null);
                    try { provider.updateMemoryCache(assetKey, null); } catch (_) {}
                    if (widget.hostModuleId != null && widget.hostModuleId!.isNotEmpty) {
                      try { provider.updateMemoryCache(widget.hostModuleId!, null); } catch (_) {}
                    }
                  } catch (e) {
                    debugPrint('Error clearing in-memory cache post-activation: $e');
                  }
                } catch (e) {
                  debugPrint('Error clearing local cache post-activation: $e');
                }
              });
              // Previously we updated the host module's settings to auto-enable
              // the extension upon activation. That behavior has been removed
              // — extensions are now activated independently and the host's
              // `extensions` list is not modified here.
            } catch (e) {
              debugPrint('Failed to cache module config locally after activation: $e');
            }
          } catch (e) {
            debugPrint('Failed to create default module config during activation: $e');
          }
        }
      } catch (e) {
        debugPrint('Error ensuring config folder during activation: $e');
      }

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
      // Register the module in the company registry under 'modules' sheet.
      try {
        final _rootRes = workspaceProvider.rootFolderId ?? (driveService as dynamic).checkRootFolder();
        dynamic rootFolderId;
        if (_rootRes is Future) {
          rootFolderId = await _rootRes;
        } else {
          rootFolderId = _rootRes;
        }
        if (rootFolderId != null) {
          final _regRes = (driveService as dynamic).registerModule(rootFolderId, workspaceId, moduleName, moduleFolderId);
          if (_regRes is Future) await _regRes;
        } else {
          debugPrint('Root folder id not available; skipping module registry write');
        }
      } catch (e) {
        debugPrint('Failed to register module in registry: $e');
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
          child: _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: AppTheme.inter(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadModuleConfig,
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                )
              : Column(
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
