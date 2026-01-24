import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/schema_service.dart';
import '../services/drive_service.dart';
import '../providers/workspace_provider.dart';
import '../providers/drive_provider.dart';
import 'dashboard_screen.dart';

class ModuleConfigurationScreen extends StatefulWidget {
  final Map<String, String> moduleInfo;

  const ModuleConfigurationScreen({super.key, required this.moduleInfo});

  @override
  State<ModuleConfigurationScreen> createState() => _ModuleConfigurationScreenState();
}

class _ModuleConfigurationScreenState extends State<ModuleConfigurationScreen> {
  bool _isLoading = true;
  bool _isActivating = false;
  Map<String, dynamic>? _moduleJson;
  final Map<String, dynamic> _formValues = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_moduleJson == null && _isLoading) {
      _loadModuleConfig();
    }
  }

  Future<void> _loadModuleConfig() async {
    try {
      final key = (widget.moduleInfo['id'] ?? widget.moduleInfo['name'])!.toString().toLowerCase().trim();
      // Load module JSON using the authoritative asset map via the
      // current AssetBundle so tests can inject a TestAssetBundle.
      final mapStr = await DefaultAssetBundle.of(context).loadString('assets/erp_modules/module_asset_map.json');
      final Map<String, dynamic> mapJson = jsonDecode(mapStr) as Map<String, dynamic>;
      final normalizedMap = <String, String>{};
      for (final entry in mapJson.entries) {
        final k = entry.key.toString().toLowerCase().trim();
        final v = entry.value?.toString() ?? '';
        if (v.isNotEmpty) normalizedMap[k] = v;
      }
      final mapped = normalizedMap[key];
      if (mapped == null || mapped.isEmpty) throw Exception('Module asset not found for key: $key');
      final jsonString = await DefaultAssetBundle.of(context).loadString('assets/erp_modules/$mapped');
      final json = jsonDecode(jsonString);
      
      setState(() {
        _moduleJson = json;
        _isLoading = false;
        
        // Initialize form values from settings
        if (json['settings'] != null) {
          final settings = json['settings'] as Map<String, dynamic>;
          settings.forEach((key, value) {
            if (value is Map && value.containsKey('value')) {
              _formValues[key] = value['value'];
            }
          });
        } else {
           _formValues['name'] = widget.moduleInfo['name'];
        }
      });
    } catch (e) {
      // Fallback if JSON not found
      setState(() {
        _isLoading = false;
        _formValues['name'] = widget.moduleInfo['name'];
      });
      debugPrint('Error loading module config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(int.parse(widget.moduleInfo['color']!.replaceAll('#', '0xFF')));
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CONFIGURE ${widget.moduleInfo['name']!.toUpperCase()}',
          style: AppTheme.inter(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customize your module',
                      style: AppTheme.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adjust the settings below to fit your business needs.',
                      style: AppTheme.inter(
                        fontSize: 16,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _buildFormFields(color, theme),
                        ),
                      ),
                    ),

                    // Activate Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isActivating ? null : _activateModule,
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isActivating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'COMPLETE SETUP',
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
              ),
            ),
    );
  }

  List<Widget> _buildFormFields(Color color, ThemeData theme) {
    if (_moduleJson == null || _moduleJson!['settings'] == null) {
      return [
        _buildTextField('Module Name', 'name', color, theme),
      ];
    }

    final settings = _moduleJson!['settings'] as Map<String, dynamic>;
    return settings.entries.map((entry) {
      final key = entry.key;
      final field = entry.value as Map<String, dynamic>;
      final label = field['label'] ?? key;
      final type = field['type'] ?? 'text';
      final dependsOn = field['dependsOn'];

      // Check dependency
      if (dependsOn != null) {
        final dependencyValue = _formValues[dependsOn];
        // Assuming dependency is boolean true for now
        if (dependencyValue != true) {
          return const SizedBox.shrink();
        }
      }

      if (type == 'text') {
        return _buildTextField(label, key, color, theme);
      } else if (type == 'select') {
        return _buildDropdownField(label, key, field['options'] ?? [], color, theme);
      } else if (type == 'boolean') {
        return _buildSwitchField(label, key, color, theme);
      } else if (type == 'list') {
        return _buildListField(label, key, color, theme);
      }
      return const SizedBox.shrink();
    }).toList();
  }

  Widget _buildListField(String label, String key, Color color, ThemeData theme) {
    List<String> items = [];
    if (_formValues[key] is List) {
      items = List<String>.from(_formValues[key]);
    } else {
      items = [];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTheme.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyMedium?.color,
                  letterSpacing: 1.0,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded, color: color),
                onPressed: () {
                  setState(() {
                    items.add("New Warehouse");
                    _formValues[key] = items;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              key: UniqueKey(),
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: item,
                      onChanged: (value) {
                        items[index] = value;
                        _formValues[key] = items;
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.cardTheme.color,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: AppTheme.inter(fontSize: 16, color: theme.textTheme.bodyLarge?.color),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        items.removeAt(index);
                        _formValues[key] = items;
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String key, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyMedium?.color,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _formValues[key]?.toString(),
            onChanged: (value) => _formValues[key] = value,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: AppTheme.inter(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String key, List<dynamic> options, Color color, ThemeData theme) {
     final List<String> strOptions = options.map((e) => e.toString()).toList();
     
     return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyMedium?.color,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _formValues[key] is String && strOptions.contains(_formValues[key]) 
                    ? _formValues[key] 
                    : (strOptions.isNotEmpty ? strOptions.first : null),
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: color),
                items: strOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _formValues[key] = newValue;
                  });
                },
                style: AppTheme.inter(
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                dropdownColor: theme.cardTheme.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField(String label, String key, Color color, ThemeData theme) {
    final value = _formValues[key] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyMedium?.color,
              letterSpacing: 1.0,
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              setState(() {
                _formValues[key] = newValue;
              });
            },
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  Future<void> _activateModule() async {
    setState(() => _isActivating = true);

    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final capturedUserEmail = authService.currentUser?.email;
      
      if (driveProvider.driveService == null || workspaceProvider.currentWorkspace == null) {
        throw Exception("Drive Service or Workspace missing");
      }

      final driveService = driveProvider.driveService!;
      final workspaceId = workspaceProvider.currentWorkspace!.id!;
      
      final moduleName = _formValues['name'] ?? widget.moduleInfo['name']!;

        // If the user already has this module in their per-user `modules` sheet
        // and it's marked `deactivated`, simply re-activate by flipping the
        // status back to `activated` and return — do not create folders or seed data.
        try {
          final userEmail = capturedUserEmail;
          if (userEmail != null && userEmail.isNotEmpty) {
            final userAccessFolderId = await (driveService as dynamic).ensureUserAccessFolder(workspaceId);
            final userAccessFileId = await (driveService as dynamic).ensureUserAccessSpreadsheet(userAccessFolderId, userEmail);

            // Read header to locate 'status' column
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
                    final moduleId = row.isNotEmpty ? row[0] : null;
                    if (moduleId != null && moduleId.isNotEmpty) {
                      await (driveService as dynamic).setUserAccessModuleStatus(userAccessFileId, moduleId, 'activated');
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
          final userEmail = capturedUserEmail;
          final configFileName = userEmail != null && userEmail.isNotEmpty ? '${userEmail}' : 'config';
          String? createdSettingsId;
          try {
            if (configFolderId != null) {
              final _createCfgRes = (driveService as dynamic).createModuleConfig(configFolderId, configFileName, _moduleJson!);
              if (_createCfgRes is Future) {
                createdSettingsId = await _createCfgRes as String?;
              } else {
                createdSettingsId = _createCfgRes as String?;
              }
            } else {
              debugPrint('Config folder not created; skipping default config creation');
            }
          } catch (e) {
            debugPrint('Failed to create default module config during activation: $e');
          }
        }
      } catch (e) {
        debugPrint('Error ensuring config folder during activation: $e');
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

          // Also ensure user's access spreadsheet is updated with this module info
          try {
            final userEmail = capturedUserEmail;
              if (userEmail != null && userEmail.isNotEmpty) {
              final userAccessFolderId = await (driveService as dynamic).ensureUserAccessFolder(workspaceId);
              final userAccessFileId = await (driveService as dynamic).ensureUserAccessSpreadsheet(userAccessFolderId, userEmail);
              final configFolderIdFetched = await (driveService as dynamic).getOrCreateSubFolder(moduleFolderId, 'config');
              final dashboardId = await (driveService as dynamic).getFileId(configFolderIdFetched, '${userEmail}_dashboard');
              final tabsId = await (driveService as dynamic).getFileId(configFolderIdFetched, '${userEmail}_tabs');
              final settingsId = await (driveService as dynamic).getFileId(configFolderIdFetched, '${userEmail}_settings');
              await (driveService as dynamic).upsertUserAccessModule(userAccessFileId, moduleFolderId, moduleName, dashboardId ?? '', settingsId ?? '', tabsId ?? '');
              try {
                await (driveService as dynamic).setUserAccessModuleStatus(userAccessFileId, moduleFolderId, 'activated');
              } catch (e) {
                debugPrint('Error setting module status to activated: $e');
              }
            }
          } catch (e) {
            debugPrint('Failed to update user access spreadsheet during module activation: $e');
          }
        } else {
          debugPrint('Root folder id not available; skipping module registry write');
        }
      } catch (e) {
        debugPrint('Failed to register module in registry: $e');
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error activating module: $e')),
        );
        setState(() => _isActivating = false);
      }
    }
  }
}
