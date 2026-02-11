import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/schema_service.dart';
import '../theme/app_theme.dart';
import '../providers/drive_provider.dart';
import '../providers/schema_provider.dart';
import '../providers/workspace_provider.dart';
import '../utils/icon_lookup.dart';
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
  String _statusMessage = "Starting activation...";
  double _progress = 0.0;
  Map<String, dynamic>? _moduleJson;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  bool _didLoadConfig = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadConfig) {
      _didLoadConfig = true;
      _loadModuleConfig();
    }
  }

  Future<void> _loadModuleConfig() async {
    try {
      final key = (widget.moduleInfo['id'] ?? widget.moduleInfo['name'])!.toString().toLowerCase().trim();
      final jsonString = await SchemaService.tryLoadModuleAsset(key, bundle: DefaultAssetBundle.of(context));
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
    setState(() {
      _isActivating = true;
      _statusMessage = "Ensuring workspace connections...";
      _progress = 0.1;
    });

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final capturedUserEmail = authService.currentUser?.email;
      
      if (driveProvider.driveService == null || workspaceProvider.currentWorkspace == null) {
        throw Exception("Authentication or Workspace missing");
      }

      final driveService = driveProvider.driveService!;
      final workspaceId = workspaceProvider.currentWorkspace!.id!;
      
      final moduleName = widget.moduleInfo['name']!;
      final assetKey = (widget.moduleInfo['id'] ?? widget.moduleInfo['name'])!.toString().toLowerCase().trim();

      // If the user's per-user `modules` sheet contains this module_name and
      // its `status` is `deactivated`, simply flip it to `activated` and
      // return — do not create folders or seed data.
      try {
        if (mounted) {
          setState(() {
            _statusMessage = "Checking module status...";
            _progress = 0.2;
          });
        }

        final userEmail = capturedUserEmail;
        final userAccessFileId = workspaceProvider.lastUserAccessSpreadsheetId;

        if (userEmail != null && userEmail.isNotEmpty && userAccessFileId != null) {
          try {
            final headerResp = await (driveService as dynamic).sheetsApi.spreadsheets.values.get(userAccessFileId, 'modules!A1:Z1');
            final headerRow = (headerResp.values != null && headerResp.values!.isNotEmpty) ? List<String>.from(headerResp.values!.first.map((e) => e.toString())) : <String>[];
            int statusIndex = headerRow.indexOf('status');

            final resp = await (driveService as dynamic).sheetsApi.spreadsheets.values.get(userAccessFileId, 'modules!A2:Z');
            final values = resp.values ?? [];
            for (final rowVals in values) {
              final row = List<String>.from(rowVals.map((e) => e.toString()));
              final rowName = row.length > 1 ? row[1] : '';
              if (rowName.trim().toLowerCase() == moduleName.toString().trim().toLowerCase()) {
                final currentStatus = (statusIndex != -1 && row.length > statusIndex) ? row[statusIndex] : '';
                if (currentStatus.toString().toLowerCase() == 'deactivated') {
                  if (mounted) {
                    setState(() {
                      _statusMessage = "Re-activating $moduleName...";
                      _progress = 0.5;
                    });
                  }

                  final moduleId = row.isNotEmpty ? row[0] : null;
                  if (moduleId != null && moduleId.isNotEmpty) {
                    await (driveService as dynamic).setUserAccessModuleStatus(userAccessFileId, moduleId, 'activated');
                    
                    if (mounted) {
                      setState(() {
                        _statusMessage = "Finalizing...";
                        _progress = 1.0;
                      });
                    }
                    await Future.delayed(const Duration(milliseconds: 500));

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$moduleName re-activated.')));
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                        (route) => false,
                      );
                    }
                    return;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error scanning user access for deactivated module: $e');
          }
        }
      } catch (e) {
        debugPrint('Error ensuring user access for re-activation check: $e');
      }

      if (mounted) {
        setState(() {
          _statusMessage = "Creating module folder...";
          _progress = 0.3;
        });
      }

      // Create the module folder in Drive
      final createdModuleRes = (driveService as dynamic).createWorkspace(workspaceId, moduleName);
      dynamic createdModule;
      if (createdModuleRes is Future) {
        createdModule = await createdModuleRes;
      } else {
        createdModule = createdModuleRes;
      }
      if (createdModule == null || createdModule.id == null) {
        throw Exception('Failed to create module folder');
      }
      final moduleFolderId = createdModule.id!;

      if (mounted) {
        setState(() {
          _statusMessage = "Configuring module defaults...";
          _progress = 0.6;
        });
      }

      // Create config folder and default config file now (so module has config immediately)
      Map<String, String>? configIds;
      try {
        if (_moduleJson != null) {
          final configFolderRes = (driveService as dynamic).getOrCreateSubFolder(moduleFolderId, 'config');
          dynamic configFolderId;
          if (configFolderRes is Future) {
            configFolderId = await configFolderRes;
          } else {
            configFolderId = configFolderRes;
          }
          if (configFolderId == null) {
            throw Exception('Failed to ensure config folder');
          }
          final userEmail = capturedUserEmail;
          final configFileName = userEmail != null && userEmail.isNotEmpty ? userEmail : 'config';
          try {
            // Create module config on Drive (capturing IDs to avoid subsequent getFileId lookups)
            dynamic createCfgRes = (driveService as dynamic).createModuleConfig(configFolderId, configFileName, _moduleJson!);
            if (createCfgRes is Future) {
              final result = await createCfgRes;
              if (result is Map) configIds = Map<String, String>.from(result);
            } else if (createCfgRes is Map) {
              configIds = Map<String, String>.from(createCfgRes);
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
        setState(() {
          _statusMessage = "Registering user access...";
          _progress = 0.9;
        });
      }

      // Update user's access spreadsheet with module config ids.
      try {
        final rootRes = workspaceProvider.rootFolderId ?? (driveService as dynamic).checkRootFolder();
        dynamic rootFolderId;
        if (rootRes is Future) {
          rootFolderId = await rootRes;
        } else {
          rootFolderId = rootRes;
        }
        if (rootFolderId != null) {
          try {
            final userEmail = capturedUserEmail;
            if (userEmail != null && userEmail.isNotEmpty) {
              // Use IDs captured during creation; avoid getFileId by filename
              final settingsId = configIds?['settings'];
              final dashboardId = configIds?['dashboard'];
              final tabsId = configIds?['tabs'];

              final userAccessFileId = workspaceProvider.lastUserAccessSpreadsheetId;

              if (userAccessFileId != null) {
                await (driveService as dynamic).upsertUserAccessModule(
                  userAccessFileId, 
                  moduleFolderId, 
                  moduleName, 
                  dashboardId ?? '', 
                  settingsId ?? '', 
                  tabsId ?? '',
                  moduleType: widget.hostModuleId != null ? 'extension' : 'module'
                );
                try {
                  await (driveService as dynamic).setUserAccessModuleStatus(userAccessFileId, moduleFolderId, 'activated');
                } catch (e) {
                  debugPrint('Error setting module status to activated: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('Failed to update user access spreadsheet during module activation: $e');
          }
        } else {
          debugPrint('Root folder id not available; skipping user access update');
        }
      } catch (e) {
        debugPrint('Failed to update user access in registry step: $e');
      }

      if (mounted) {
        setState(() {
          _statusMessage = "Module ready!";
          _progress = 1.0;
        });
      }
      await Future.delayed(const Duration(milliseconds: 500));

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
      body: _isActivating
          ? _buildActivationProgress(theme, color)
          : SafeArea(
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
                    iconFromName(iconName),
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

  // Icons are resolved via `iconFromName` in `lib/utils/icon_lookup.dart`.

  Widget _buildActivationProgress(ThemeData theme, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 64),
            Text(
              'ACTIVATING MODULE',
              style: AppTheme.inter(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 12,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusMessage,
                key: ValueKey<String>(_statusMessage),
                style: AppTheme.sourceCodePro(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: theme.cardTheme.color,
                color: color,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${(_progress * 100).toInt()}% Complete',
              style: AppTheme.inter(
                color: theme.disabledColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
