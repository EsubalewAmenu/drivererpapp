import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../providers/schema_provider.dart';
import '../services/schema_service.dart';
import 'schema_editor_screen.dart';
import 'module/module_dashboard.dart';
import 'module/module_tab_screen.dart';
import 'common/history_dialog.dart';
import 'module_details_screen.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import '../utils/icon_lookup.dart';

class ModuleScreen extends StatefulWidget {
  final ModuleSchema module;
  final String? settingsSheetId;
  final String? dashboardSheetId;
  final String? tabsSheetId;
  const ModuleScreen({
    super.key,
    required this.module,
    this.settingsSheetId,
    this.dashboardSheetId,
    this.tabsSheetId,
  });

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  ModuleSchema? _fullModule;
  ModuleSchema? _baseModule;
  bool _isLoadingSchema = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
    _fullModule = schemaProvider.getFromMemory(widget.module.id);
    
    _loadSchema();
  }

  Widget _buildExtensionsTab(ModuleSchema module, Color primaryColor) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadEnabledModules(module),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text('No extensions available', style: AppTheme.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3 / 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final it = items[index];
              final name = it['name'] as String? ?? it['id'] as String;
              final iconName = it['icon'] as String? ?? '';
              final activated = it['activated'] as bool? ?? false;
              // Resolve the extension's own primary color; fall back to host color
              final extColorHex = it['primaryColor'] as String? ?? module.primaryColor;
              Color extColor;
              try {
                extColor = Color(int.parse(extColorHex.replaceAll('#', '0xFF')));
              } catch (_) {
                extColor = primaryColor;
              }
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () async {
                    if (activated) {
                      // Open blueprint editor for activated module
                      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
                      ModuleSchema? mod = schemaProvider.getFromMemory(it['id'] as String);

                      // If not cached, try to load authoritative asset (includes tabs)
                      if (mod == null) {
                        try {
                          final jsonString = await SchemaService.tryLoadModuleAsset(it['id'] as String);
                          if (jsonString != null) {
                            final parsed = jsonDecode(jsonString) as Map<String, dynamic>;

                            // Parse settings
                            final settingsRaw = parsed['settings'];
                            final settingsMap = <String, SettingItem>{};
                            if (settingsRaw != null && settingsRaw is Map<String, dynamic>) {
                              settingsRaw.forEach((k, v) {
                                try {
                                  settingsMap[k] = SettingItem.fromJson(Map<String, dynamic>.from(v as Map));
                                } catch (_) {}
                              });
                            }

                            // Parse dashboard
                            final dashboardJson = parsed['dashboard'] != null ? Map<String, dynamic>.from(parsed['dashboard'] as Map) : null;
                            final dashboard = (dashboardJson != null && dashboardJson['cards'] != null)
                                ? DashboardConfig.fromJson(dashboardJson)
                                : DashboardConfig(cards: []);

                            // Parse tabs
                            final tabsRaw = parsed['tabs'];
                            final tabsList = tabsRaw != null ? List<dynamic>.from(tabsRaw as List) : [];
                            final tabs = tabsList.map((t) {
                              try {
                                return TabConfig.fromJson(Map<String, dynamic>.from(t as Map));
                              } catch (_) {
                                return TabConfig(id: 'err', label: 'Error Tab', columns: []);
                              }
                            }).toList();

                            mod = ModuleSchema(
                              id: it['id'] as String,
                              name: name,
                              icon: iconName,
                              primaryColor: _colorToHex(primaryColor),
                              version: '1.0',
                              settings: settingsMap,
                              dashboard: dashboard,
                              tabs: tabs,
                            );

                            // Cache for future lookups
                            schemaProvider.updateMemoryCache(mod.id, mod);
                          }
                        } catch (_) {}
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SchemaEditorScreen(module: mod ?? ModuleSchema(id: it['id'] as String, name: name, icon: iconName, primaryColor: '#2196F3', version: '1.0', settings: {}, dashboard: DashboardConfig(cards: []), tabs: []))),
                      ).then((_) => _loadSchema());
                    } else {
                      // Go to activation/details page
                      final info = {
                        'id': it['id'] as String,
                        'name': it['name'] as String? ?? it['id'] as String,
                        'desc': it['desc'] as String? ?? '',
                        'icon': it['icon'] as String? ?? '',
                        'color': it['primaryColor'] as String? ?? '#2196F3',
                      };
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ModuleDetailsScreen(moduleInfo: Map<String,String>.from(info), hostModuleId: widget.module.id)),
                      ).then((_) => _loadSchema());
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: extColor.withOpacity(0.12),
                                child: Icon(iconFromName(iconName), color: extColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name, style: AppTheme.inter(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(activated ? 'Installed' : 'Install', style: AppTheme.inter(fontSize: 12, color: Colors.grey)),
                            Icon(activated ? Icons.check_circle_rounded : Icons.download_rounded, color: activated ? Colors.green : Colors.grey)
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadEnabledModules(ModuleSchema module) async {
    final result = <Map<String, dynamic>>[];
    try {
      final settings = module.settings;
      final extSetting = settings['extensions'];
      final enabledKeys = <String>[];
      if (extSetting != null && extSetting.value is List) {
        enabledKeys.addAll((extSetting.value as List).map((e) => e.toString()));
      }
      if (enabledKeys.isEmpty) return result;

      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      final driveService = driveProvider.driveService;
      final workspaceId = Provider.of<WorkspaceProvider>(context, listen: false).currentWorkspace?.id;
      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);

      List<dynamic> activeModules = [];
      try {
        if (driveService != null && workspaceId != null) {
          activeModules = await driveService.listModules(workspaceId);
        }
      } catch (_) {}

      for (var rawKey in enabledKeys) {
        try {
          final key = rawKey.toString();
          final modId = key; // extensions list contains authoritative module asset keys

          final cached = schemaProvider.findModuleByIdOrName(modId);
          String name = cached?.name ?? modId;
          String icon = cached?.icon ?? '';
          String desc = '';
          String primaryColor = cached?.primaryColor ?? '#2196F3';

          try {
            final jsonString = await SchemaService.tryLoadModuleAsset(modId);
            if (jsonString != null) {
              final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
              final settingsRaw = parsed['settings'] as Map<String, dynamic>?;
              if (settingsRaw != null) {
                name = settingsRaw['name']?['value']?.toString() ?? name;
                icon = settingsRaw['icon']?['value']?.toString() ?? icon;
                primaryColor = settingsRaw['primaryColor']?['value']?.toString() ?? primaryColor;
              }
              desc = parsed['desc']?.toString() ?? desc;
            }
          } catch (_) {}

          var activated = false;
          try {
            for (var m in activeModules) {
              final mName = (m.name ?? '').toString().toLowerCase();
              if (mName == modId.toLowerCase() || mName == name.toLowerCase()) {
                activated = true;
                break;
              }
            }
          } catch (_) {}

          result.add({
            'id': modId,
            'name': name,
            'icon': icon,
            'desc': desc,
            'primaryColor': primaryColor,
            'activated': activated,
          });
          debugPrint('Enabled module entry -> id:$modId name:$name icon:$icon primaryColor:$primaryColor activated:$activated');
        } catch (e) {
          debugPrint('Error loading enabled module entry "${rawKey}": $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error loading enabled modules: $e');
    }
    return result;
  }

  // Icons are resolved via `iconFromName` in `lib/utils/icon_lookup.dart`.

  String _colorToHex(Color c) {
    // Return #RRGGBB (drop alpha)
    final hex = c.value.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}';
  }

  Future<void> _loadSchema() async {
    debugPrint('ModuleScreen: Starting _loadSchema for ${widget.module.id}');
    debugPrint('Provided sheet ids -> settings:${widget.settingsSheetId} dashboard:${widget.dashboardSheetId} tabs:${widget.tabsSheetId}');
    try {
      final schemaService = Provider.of<SchemaProvider>(context, listen: false).service;
      
      // 1. Try to load from cache
      final cachedJson = await schemaService.getCachedConfig(widget.module.id);
      if (cachedJson != null) {
        debugPrint('Loading module ${widget.module.id} from cache...');
        await _processJson(cachedJson);
        
        // Background sync after UI settles
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _syncSchema(schemaService);
        });
        return;
      }

      debugPrint('ModuleScreen: Not in cache, calling _syncSchema');
      // 2. Not in cache, start sync in background
      _syncSchema(schemaService).then((newJson) async {
        debugPrint('ModuleScreen: _syncSchema finished with ${newJson != null}');
        if (newJson == null && mounted) {
          // 3. Fallback to Assets if no remote config
          debugPrint('No remote config found for ${widget.module.id}, checking assets...');
          final fileName = widget.module.name.toLowerCase();
          Map<String, dynamic> assetJson;
            try {
                final jsonString = await SchemaService.tryLoadModuleAsset(fileName);
                if (jsonString != null) {
                  assetJson = jsonDecode(jsonString);
                } else {
                  throw Exception('Asset not found');
                }
              } catch (e) {
            debugPrint('Asset not found for $fileName, using default template');
            // If no remote config AND no asset, use a basic template and go to editor
            assetJson = {
              'settings': {
                'name': {'label': 'Name', 'type': 'text', 'value': widget.module.name}
              },
              'dashboard': {'cards': []},
              'tabs': [],
            };
          }
          await _processJson(assetJson, isAssetFallback: true);
        }
      });

    } catch (e) {
      debugPrint('Error in _loadSchema sequence: $e');
    }
  }

  Future<Map<String, dynamic>?> _syncSchema(SchemaService schemaService) async {
    debugPrint('ModuleScreen: _syncSchema started');
    try {
      final driveService = schemaService.driveService;

      // If explicit per-user sheet ids were provided, prefer reading by those ids
      if (driveService != null && widget.settingsSheetId != null && widget.settingsSheetId!.isNotEmpty) {
        try {
          debugPrint('Attempting direct read of settings spreadsheet id=${widget.settingsSheetId}');
          var newConfig = await driveService.readModuleConfig(widget.settingsSheetId!);

          // If readModuleConfig didn't populate dashboard/tabs but explicit ids were provided, try manual reads
          if ((newConfig == null || newConfig['dashboard'] == null) && widget.dashboardSheetId != null && widget.dashboardSheetId!.isNotEmpty) {
            try {
              debugPrint('Reading dashboard directly from id=${widget.dashboardSheetId}');
              final resp = await driveService.sheetsApi.spreadsheets.values.get(widget.dashboardSheetId!, 'cards!A1:Z');
              if (resp.values != null && resp.values!.isNotEmpty) {
                final firstRow = resp.values!.first;
                if (firstRow.isNotEmpty && firstRow.first is String && (firstRow.first as String).trim().startsWith('{')) {
                  newConfig ??= <String, dynamic>{};
                  newConfig['dashboard'] = resp.values!.map((r) => jsonDecode(r.first as String)).toList();
                } else {
                  // try map form
                  try {
                    final mapResp = await driveService.sheetsApi.spreadsheets.values.get(widget.dashboardSheetId!, 'cards!A:B');
                    final map = <String, dynamic>{};
                    if (mapResp.values != null) {
                      for (var row in mapResp.values!) {
                        if (row.length >= 2) map[row[0] as String] = jsonDecode(row[1] as String);
                      }
                      newConfig ??= <String, dynamic>{};
                      newConfig['dashboard'] = map;
                    }
                  } catch (e) {
                    debugPrint('Error reading dashboard map fallback: $e');
                  }
                }
              }
            } catch (e) {
              debugPrint('Error reading dashboard by id: $e');
            }
          }

          if ((newConfig == null || newConfig['tabs'] == null) && widget.tabsSheetId != null && widget.tabsSheetId!.isNotEmpty) {
            try {
              debugPrint('Reading tabs directly from id=${widget.tabsSheetId}');
              final ss = await driveService.sheetsApi.spreadsheets.get(widget.tabsSheetId!);
              final sheetTitles = ss.sheets?.map((s) => s.properties?.title ?? '').where((t) => t.isNotEmpty).toList() ?? [];
              final tabs = <dynamic>[];
              for (var title in sheetTitles) {
                try {
                  final resp = await driveService.sheetsApi.spreadsheets.values.get(widget.tabsSheetId!, '$title!A1');
                  if (resp.values != null && resp.values!.isNotEmpty) {
                    final cell = resp.values!.first.first;
                    if (cell is String) {
                      tabs.add(jsonDecode(cell));
                    }
                  }
                } catch (e) {
                  debugPrint('Error reading tab $title: $e');
                }
              }
              if (tabs.isNotEmpty) {
                newConfig ??= <String, dynamic>{};
                newConfig['tabs'] = tabs;
              }
            } catch (e) {
              debugPrint('Error reading tabs by id: $e');
            }
          }

          if (newConfig != null) {
            debugPrint('Module ${widget.module.id} schema loaded directly from spreadsheets.');
            // Cache with metadata
            try {
              final modifiedTime = await driveService.getFileModifiedTime(widget.settingsSheetId!);
              await schemaService.cacheConfig(widget.module.id, newConfig, fileId: widget.settingsSheetId, modifiedTime: modifiedTime?.toIso8601String());
            } catch (e) {
              debugPrint('Error caching direct-read config: $e');
            }
            if (mounted) await _processJson(newConfig);
          }
          return newConfig;
        } catch (e) {
          debugPrint('Direct read by sheet ids failed: $e');
          // fallthrough to normal sync below
        }
      }

      final newJson = await schemaService.syncConfig(widget.module.id);
      if (newJson != null && mounted) {
        debugPrint('Module ${widget.module.id} schema updated from Drive.');
        await _processJson(newJson);
      }
      return newJson;
    } catch (e) {
      debugPrint('Sync error: $e');
      return null;
    }
  }

  Future<void> _processJson(Map<String, dynamic> jsonMap, {bool isAssetFallback = false}) async {
    if (!mounted) return;
    
    try {
      // Parse JSON to ModuleSchema
      final settingsRaw = jsonMap['settings'];
      final settingsMap = settingsRaw != null ? Map<String, dynamic>.from(settingsRaw as Map) : <String, dynamic>{};
      final name = settingsMap['name']?['value']?.toString() ?? widget.module.name;
      
      final icon = settingsMap['icon']?['value']?.toString() ?? jsonMap['icon']?.toString() ?? widget.module.icon;
      final primaryColor = settingsMap['primaryColor']?['value']?.toString() ?? jsonMap['primaryColor']?.toString() ?? widget.module.primaryColor;
      final version = settingsMap['version']?['value']?.toString() ?? jsonMap['version']?.toString() ?? widget.module.version;
      
      final dashboardRaw = jsonMap['dashboard'];
      final dashboardJson = dashboardRaw != null ? Map<String, dynamic>.from(dashboardRaw as Map) : null;
      final dashboard = (dashboardJson != null && dashboardJson['cards'] != null)
          ? DashboardConfig.fromJson(dashboardJson)
          : DashboardConfig(cards: []);
      
      final tabsRaw = jsonMap['tabs'];
      final tabsList = tabsRaw != null ? List<dynamic>.from(tabsRaw as List) : [];
      
      // Pre-process tabs
      for (var i = 0; i < tabsList.length; i++) {
        final tab = Map<String, dynamic>.from(tabsList[i] as Map);
        if (tab['columns'] == null) {
          tab['columns'] = [];
        }
        
        final columns = List<dynamic>.from(tab['columns'] as List);
        for (var j = 0; j < columns.length; j++) {
          final col = columns[j];
          if (col is Map && col['options'] is String && (col['options'] as String).startsWith('settings.')) {
            final path = (col['options'] as String).split('.');
            if (path.length == 2) {
              final settingKey = path[1];
              final settingValue = settingsMap[settingKey]?['value'];
              
              final colMap = Map<String, dynamic>.from(col);
              if (settingValue is List) {
                colMap['options'] = settingValue;
              } else {
                colMap['options'] = [];
              }
              columns[j] = colMap;
            }
          }
        }
        tab['columns'] = columns;
        tabsList[i] = tab;
      }

      final tabs = (tabsList as List).map((t) {
        try {
          final parsed = TabConfig.fromJson(t as Map<String, dynamic>);
          debugPrint('Loaded tab: ${parsed.label}');
          return parsed;
        } catch (e) {
          debugPrint('Error parsing tab: $e');
          return TabConfig(id: 'err', label: 'Error Tab', columns: []);
        }
      }).toList();

      final settingsItems = <String, SettingItem>{};
      settingsMap.forEach((k, v) {
        try {
          if (v != null && v is Map<String, dynamic>) {
            settingsItems[k] = SettingItem.fromJson(v);
          } else if (v != null && v is List) {
            // e.g. extensions defined inside 'settings' as a plain list
            settingsItems[k] = SettingItem(label: k, type: 'list', value: v);
          } else if (v != null) {
            // Primitive value; wrap as a simple SettingItem
            settingsItems[k] = SettingItem(label: k, type: 'text', value: v);
          }
        } catch (e) {
          debugPrint('Error parsing setting $k: $e');
        }
      });

      // Read top-level extensions array (new format) and expose it via settings
      // so existing UI helpers can read it.
      try {
        final extensionsRaw = jsonMap['extensions'];
        if (extensionsRaw is List) {
          final exList = extensionsRaw.map((e) => e.toString()).toList();
          settingsItems['extensions'] = SettingItem(label: 'Extensions', type: 'list', value: exList);
        }
      } catch (_) {}

      final loadedModule = ModuleSchema(
        id: widget.module.id,
        name: name,
        icon: icon,
        primaryColor: primaryColor,
        version: version,
        settings: settingsItems,
        dashboard: dashboard,
        tabs: tabs,
      );

      // Keep the original loaded module (without tabs merged from enabled modules)
      _baseModule = loadedModule;

      // If module lists extensions explicitly (preferred) use that list.
      final combinedTabs = <TabConfig>[];
      combinedTabs.addAll(tabs);

      // Only use explicit `extensions` list
      final List<String> extensionKeys = [];
      final extSetting = settingsItems['extensions'];
      if (extSetting != null && extSetting.value is List) {
        extensionKeys.addAll((extSetting.value as List).map((e) => e.toString()));
      }

      // Determine which extensions are activated in the current workspace so
      // we only merge tabs from modules that are actually installed. Wrap
      // provider lookups in try/catch so isolated widget tests that don't
      // provide Drive/Workspace providers don't crash.
      final installedNames = <String>{};
      try {
        final driveProvider = Provider.of<DriveProvider>(context, listen: false);
        final driveService = driveProvider.driveService;
        final workspaceId = Provider.of<WorkspaceProvider>(context, listen: false).currentWorkspace?.id;
        if (driveService != null && workspaceId != null) {
          final activeModules = await driveService.listModules(workspaceId);
          for (var m in activeModules) {
            final name = (m.name ?? '').toString().toLowerCase();
            installedNames.add(name);
          }
        }
      } catch (e) {
        debugPrint('Could not determine installed modules (missing providers?): $e');
      }

      for (final otherModuleId in extensionKeys) {
          try {
            ModuleSchema? otherModule = Provider.of<SchemaProvider>(context, listen: false).getFromMemory(otherModuleId);
            Map<String, dynamic>? otherJson;
            if (otherModule == null) {
              // Try to load from assets by module id/name
              try {
                final jsonString = await SchemaService.tryLoadModuleAsset(otherModuleId);
                if (jsonString != null) {
                  otherJson = jsonDecode(jsonString) as Map<String, dynamic>;
                } else {
                  otherJson = null;
                }
              } catch (_) {
                otherJson = null;
              }

              if (otherJson != null) {
                // Parse the other module's tabs similarly to above
                final otherSettingsRaw = otherJson['settings'];
                final otherSettingsMap = otherSettingsRaw != null ? Map<String, dynamic>.from(otherSettingsRaw as Map) : <String, dynamic>{};

                // Check activation: ensure this extension module is installed in
                // the workspace before merging its tabs into the host module.
                final candidateName = (otherSettingsMap['name']?['value']?.toString() ?? otherModuleId).toLowerCase();
                if (!installedNames.contains(candidateName) && !installedNames.contains(otherModuleId.toLowerCase())) {
                  // Not installed — skip merging tabs from this extension.
                  continue;
                }
                final otherTabsRaw = otherJson['tabs'];
                final otherTabsList = otherTabsRaw != null ? List<dynamic>.from(otherTabsRaw as List) : [];

                // Pre-process columns for options that reference settings
                for (var i = 0; i < otherTabsList.length; i++) {
                  final tab = Map<String, dynamic>.from(otherTabsList[i] as Map);
                  if (tab['columns'] == null) tab['columns'] = [];
                  final columns = List<dynamic>.from(tab['columns'] as List);
                  for (var j = 0; j < columns.length; j++) {
                    final col = columns[j];
                    if (col is Map && col['options'] is String && (col['options'] as String).startsWith('settings.')) {
                      final path = (col['options'] as String).split('.');
                      if (path.length == 2) {
                        final settingKey = path[1];
                        final settingValue = otherSettingsMap[settingKey]?['value'];
                        final colMap = Map<String, dynamic>.from(col);
                        if (settingValue is List) {
                          colMap['options'] = settingValue;
                        } else {
                          colMap['options'] = [];
                        }
                        columns[j] = colMap;
                      }
                    }
                  }
                  tab['columns'] = columns;
                  otherTabsList[i] = tab;
                }

                final parsedOtherTabs = (otherTabsList as List).map((t) {
                  try {
                    return TabConfig.fromJson(t as Map<String, dynamic>);
                  } catch (e) {
                    return TabConfig(id: 'err', label: 'Error Tab', columns: []);
                  }
                }).toList();

                // Prefix ids to avoid collisions and mark origin. Use the authoritative
                // module id from the other module's settings if available (not the
                // display name), so tab ids remain consistent with the source config.
                final authoritativeOtherId = otherSettingsMap['id']?['value']?.toString() ?? otherModuleId;

                // If this extension is installed in the workspace, prefer the Drive folder id
                String moduleIdForCache = authoritativeOtherId;
                try {
                  List<dynamic> _activeModules = [];
                  final driveProvider = Provider.of<DriveProvider>(context, listen: false);
                  final driveService = driveProvider.driveService;
                  final workspaceId = Provider.of<WorkspaceProvider>(context, listen: false).currentWorkspace?.id;
                  if (driveService != null && workspaceId != null) {
                    _activeModules = await driveService.listModules(workspaceId);
                  }
                  for (var m in _activeModules) {
                    final mName = (m.name ?? '').toString().toLowerCase();
                    if (mName == candidateName || mName == otherModuleId.toLowerCase()) {
                      moduleIdForCache = m.id ?? authoritativeOtherId;
                      break;
                    }
                  }
                } catch (_) {}

                for (var ot in parsedOtherTabs) {
                  final newId = authoritativeOtherId == ot.id ? ot.id : '${authoritativeOtherId}_${ot.id}';
                  combinedTabs.add(ot.copyWith(id: newId));
                }

                // Cache a minimal ModuleSchema for the enabled module so later
                // lookups by id/name resolve correctly when building tabs.
                try {
                  final otherModuleName = otherSettingsMap['name']?['value']?.toString() ?? otherModuleId;
                  final otherIcon = otherSettingsMap['icon']?['value']?.toString() ?? '';
                  final otherPrimary = otherSettingsMap['primaryColor']?['value']?.toString() ?? '#2196F3';
                  final otherVersion = otherSettingsMap['version']?['value']?.toString() ?? '1.0';
                  final authoritativeOtherId = otherSettingsMap['id']?['value']?.toString() ?? otherModuleId;
                  // Normalize other module settings into SettingItem map
                  final otherSettingsItems = <String, SettingItem>{};
                  otherSettingsMap.forEach((k, v) {
                    try {
                      if (v != null && v is Map<String, dynamic>) {
                        otherSettingsItems[k] = SettingItem.fromJson(v);
                      } else if (v != null && v is List) {
                        otherSettingsItems[k] = SettingItem(label: k, type: 'list', value: v);
                      } else if (v != null) {
                        otherSettingsItems[k] = SettingItem(label: k, type: 'text', value: v);
                      }
                    } catch (_) {}
                  });

                  final otherDashboardJson = otherJson['dashboard'] != null ? Map<String, dynamic>.from(otherJson['dashboard'] as Map) : null;
                  final otherDashboard = (otherDashboardJson != null && otherDashboardJson['cards'] != null)
                      ? DashboardConfig.fromJson(otherDashboardJson)
                      : DashboardConfig(cards: []);

                  final otherModuleSchema = ModuleSchema(
                    id: moduleIdForCache,
                    name: otherModuleName,
                    icon: otherIcon,
                    primaryColor: otherPrimary,
                    version: otherVersion,
                    settings: otherSettingsItems,
                    dashboard: otherDashboard,
                    tabs: parsedOtherTabs,
                  );
                  final provider = Provider.of<SchemaProvider>(context, listen: false);
                  provider.updateMemoryCache(moduleIdForCache, otherModuleSchema);

                  // Cache the raw other module JSON so per-tab fileId entries (if any)
                  // are available to ModuleTabScreen when resolving fileIds later.
                  try {
                    await provider.service.cacheConfig(moduleIdForCache, otherJson);
                    // Also cache under the authoritative asset key for lookups by asset id
                    if (moduleIdForCache != authoritativeOtherId) {
                      await provider.service.cacheConfig(authoritativeOtherId, otherJson);
                    }
                  } catch (_) {}
                } catch (_) {}
              }
            } else {
              // Append tabs from loaded otherModule
              // Use the actual other module id when prefixing (this is authoritative)
              String moduleIdForCache = otherModule.id;
              try {
                List<dynamic> _activeModules = [];
                final driveProvider = Provider.of<DriveProvider>(context, listen: false);
                final driveService = driveProvider.driveService;
                final workspaceId = Provider.of<WorkspaceProvider>(context, listen: false).currentWorkspace?.id;
                if (driveService != null && workspaceId != null) {
                  _activeModules = await driveService.listModules(workspaceId);
                }
                for (var m in _activeModules) {
                  final mName = (m.name ?? '').toString().toLowerCase();
                  if (mName == otherModule.name.toLowerCase() || mName == otherModule.id.toLowerCase()) {
                    moduleIdForCache = m.id ?? otherModule.id;
                    break;
                  }
                }
              } catch (_) {}

              // If the preferred id differs, update memory cache key so lookups use folder id
              if (moduleIdForCache != otherModule.id) {
                final provider = Provider.of<SchemaProvider>(context, listen: false);
                provider.updateMemoryCache(moduleIdForCache, otherModule);
                try {
                  await provider.service.cacheConfig(moduleIdForCache, otherModule.toJson());
                } catch (_) {}
              }

              for (var ot in otherModule.tabs) {
                final newId = otherModule.id == ot.id ? ot.id : '${otherModule.id}_${ot.id}';
                combinedTabs.add(ot.copyWith(id: newId));
              }
            }
          } catch (e) {
            debugPrint('Error loading enabled module $otherModuleId: $e');
          }
      }

      final mergedModule = ModuleSchema(
        id: loadedModule.id,
        name: loadedModule.name,
        icon: loadedModule.icon,
        primaryColor: loadedModule.primaryColor,
        version: loadedModule.version,
        settings: loadedModule.settings,
        dashboard: loadedModule.dashboard,
        tabs: combinedTabs,
      );

      // Update memory cache for instant access next time
      Provider.of<SchemaProvider>(context, listen: false).updateMemoryCache(widget.module.id, mergedModule);

      if (mounted) {
        setState(() {
          _fullModule = mergedModule;
          _isLoadingSchema = false;
        });
      }

      // If it was an asset fallback, navigate to Editor
      if (isAssetFallback && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SchemaEditorScreen(
              module: loadedModule,
              isNewSetup: true,
            ),
          ),
        ).then((_) {
          _loadSchema();
        });
      }
    } catch (e, stack) {
      debugPrint('Error in _processJson: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() {
          _errorMessage = "Error parsing blueprint: $e";
          _isLoadingSchema = false;
        });
      }
    }
  }

  Future<void> _showHistory(BuildContext context, ModuleSchema module, String? fileName) async {
    final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
    if (driveService == null) return;
    
    showDialog(
      context: context,
      builder: (context) => HistoryDialog(
        moduleId: module.id,
        moduleName: module.name,
        fileName: fileName,
        driveService: driveService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to SchemaProvider for updates to the module configuration
    final schemaProvider = context.watch<SchemaProvider>();
    final cachedModule = schemaProvider.getFromMemory(widget.module.id);
    
    // Basic module info is always available even if full schema is loading
    final module = cachedModule ?? _fullModule ?? widget.module;
    final primaryColor = Color(int.parse(module.primaryColor.replaceAll('#', '0xFF')));
    final theme = Theme.of(context);

    return DefaultTabController(
      key: ValueKey('module_tabs_${module.id}_${module.tabs.length}'),
      length: (module.tabs.length) + 2, // +1 for Dashboard, +1 for Extensions
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            module.name.toUpperCase(),
            style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: theme.textTheme.titleLarge?.color),
          ),
          centerTitle: true,
          backgroundColor: theme.appBarTheme.backgroundColor,
          iconTheme: theme.iconTheme,
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Version History',
                onPressed: () {
                  final index = DefaultTabController.of(context).index;
                  String? fileName;
                  final baseName = module.name.toLowerCase();

                  // New config layout stores module config across three spreadsheets:
                  // `${baseName}_settings`, `${baseName}_dashboard`, `${baseName}_tabs`.
                  // Map the selected tab to the appropriate spreadsheet file name.
                  if (index == 0) {
                    fileName = '${baseName}_settings';
                  } else if (index > 0 && index <= module.tabs.length) {
                    fileName = '${baseName}_tabs';
                  } else {
                    // Extensions tab or unknown — no file to show
                    fileName = null;
                  }

                  _showHistory(context, module, fileName);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Edit Blueprint',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SchemaEditorScreen(module: _baseModule ?? cachedModule ?? widget.module)),
                ).then((_) {
                  // Reload the schema when callback from editor
                  _loadSchema();
                });
              },
            ),
          ],
          elevation: 0,
            bottom: TabBar(
            isScrollable: true,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            labelStyle: AppTheme.inter(fontWeight: FontWeight.w700),
            tabs: [
              const Tab(text: 'DASHBOARD'),
              ...module.tabs.map((t) => Tab(text: t.label.toUpperCase())),
              const Tab(text: 'EXTENSIONS'),
            ],
          ),
        ),
        body: _errorMessage != null
            ? _buildErrorBody(theme)
            : (module.tabs.isEmpty && _fullModule == null)
                ? _buildInitialLoadingBody(theme)
                : TabBarView(
                children: [
                  ModuleDashboard(module: module, primaryColor: primaryColor),
                  ...module.tabs.map((t) {
                    // Determine source module for this tab. Tabs may be prefixed
                    // like '{moduleId}_tabid' or may use the authoritative tab id
                    // (e.g. 'tickets') — attempt to resolve the real module from
                    // the cache so data fetches use the external module's folder.
                    ModuleSchema sourceModule = module;
                    try {
                      final parts = t.id.split('_');
                      if (parts.length > 1) {
                        final prefix = parts[0];
                        final candidate = Provider.of<SchemaProvider>(context, listen: false).getFromMemory(prefix);
                        if (candidate != null) {
                          sourceModule = candidate;
                        }
                      }

                      // If still unresolved (common when tab id is just 'tickets'),
                      // search cached modules to find one that contains this tab id.
                      if (sourceModule == module) {
                        final byTab = Provider.of<SchemaProvider>(context, listen: false).findModuleByTabId(t.id);
                        if (byTab != null) sourceModule = byTab;
                      }
                    } catch (_) {}

                    return ModuleTabScreen(
                      tab: t,
                      primaryColor: primaryColor,
                      settings: sourceModule.settings,
                      module: sourceModule,
                    );
                  }),
                  _buildExtensionsTab(module, primaryColor),
                ],
              ),
      ),
    );
  }

  Widget _buildInitialLoadingBody(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          Text(
            'LOADING BLUEPRINT...',
            style: AppTheme.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodySmall?.color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBody(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Error Loading Module',
            style: AppTheme.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadSchema,
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }
}
