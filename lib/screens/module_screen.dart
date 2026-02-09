import 'dart:convert';
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
  String? _errorMessage;

  // Track spreadsheet IDs for the host module and any enabling extensions
  final Map<String, String> _settingsSheetIds = {};
  final Map<String, String> _dashboardSheetIds = {};
  final Map<String, String> _tabsSheetIds = {};
  final Map<String, String> _tabSourceModuleIds = {};

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
                      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
                      ModuleSchema? mod = schemaProvider.getFromMemory(it['id'] as String);

                      // If not in memory, try cache only (no asset fallback for active extensions)
                      if (mod == null) {
                        final cached = await schemaProvider.service.getCachedConfig(it['id'] as String);
                        if (cached != null) {
                          try {
                            // Extract values from cached settings part
                            final sMap = cached['settings'] != null ? Map<String, dynamic>.from(cached['settings'] as Map) : <String, dynamic>{};
                            final n = sMap['name']?['value'] ?? it['name'] ?? it['id'];
                            final ic = sMap['icon']?['value'] ?? it['icon'] ?? 'extension';
                            final pc = sMap['primaryColor']?['value'] ?? it['primaryColor'] ?? '#2196F3';
                            final v = sMap['version']?['value'] ?? '1.0';

                            final sItems = <String, SettingItem>{};
                            sMap.forEach((k, value) {
                              if (value is Map) {
                                try { sItems[k] = SettingItem.fromJson(Map<String, dynamic>.from(value)); } catch (_) {}
                              }
                            });

                            final d = cached['dashboard'] != null 
                              ? DashboardConfig.fromJson(Map<String, dynamic>.from(cached['dashboard'] as Map)) 
                              : DashboardConfig(cards: []);
                            
                            final tList = cached['tabs'] != null ? List<dynamic>.from(cached['tabs'] as List) : [];
                            final tItems = tList.map((t) => TabConfig.fromJson(Map<String, dynamic>.from(t as Map))).toList();

                            mod = ModuleSchema(
                              id: it['id'] as String,
                              name: n.toString(),
                              icon: ic.toString(),
                              primaryColor: pc.toString(),
                              version: v.toString(),
                              settings: sItems,
                              dashboard: d,
                              tabs: tItems,
                            );
                          } catch (e) {
                            debugPrint('Error reconstructing module from cache: $e');
                          }
                        }
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SchemaEditorScreen(
                            module: mod ?? ModuleSchema(id: it['id'] as String, name: name, icon: iconName, primaryColor: '#2196F3', version: '1.0', settings: {}, dashboard: DashboardConfig(cards: []), tabs: []),
                            settingsSheetId: _settingsSheetIds[it['id']] ?? it['settingsSheetId'],
                            dashboardSheetId: _dashboardSheetIds[it['id']] ?? it['dashboardSheetId'],
                            tabsSheetId: _tabsSheetIds[it['id']] ?? it['tabsSheetId'],
                          )
                        ),
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
      final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);

      List<List<dynamic>> uaRows = [];
      // Build a set of deactivated module ids from the per-user user_access spreadsheet (if available)
      final deactivated = <String>{};
      try {
        final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
        String? uaId = workspaceProvider.lastUserAccessSpreadsheetId;
        if (uaId == null || uaId.isEmpty) uaId = await WorkspaceProvider.getLastUserAccessSpreadsheetId();
        if (uaId != null && uaId.isNotEmpty && driveService != null) {
          try {
            final resp = await driveService.sheetsApi.spreadsheets.values.get(uaId, 'modules!A1:Z');
            final all = resp.values ?? [];
            if (all.isNotEmpty) {
              final header = List<String>.from(all.first.map((e) => e.toString().toLowerCase()));
              final rows = all.length > 1 ? all.sublist(1) : [];
              uaRows = rows.map((r) => List<dynamic>.from(r as List)).toList();
              final statusIdx = header.indexOf('status');
              if (statusIdx != -1) {
                for (var r in uaRows) {
                  final id = r.isNotEmpty ? (r[0]?.toString() ?? '') : '';
                  final status = (r.length > statusIdx ? (r[statusIdx] ?? '') : '').toString().toLowerCase();
                  if (id.isNotEmpty && status == 'deactivated') deactivated.add(id);
                }
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
      // active modules are determined from the per-user user_access spreadsheet
      // (do not fall back to Drive folder listing).

      for (var rawKey in enabledKeys) {
        try {
          final key = rawKey.toString();
          final modId = key;

          final cached = schemaProvider.findModuleByIdOrName(modId);
          String name = cached?.name ?? modId;
          String icon = cached?.icon ?? '';
          String desc = '';
          String primaryColor = cached?.primaryColor ?? '#2196F3';

          var activated = false;
          String? extSettingsId;
          String? extDashboardId;
          String? extTabsId;
          String? rowId;

          try {
            // If we have a user_access rows snapshot, check for a matching id/name
            if (uaRows.isNotEmpty) {
              for (var r in uaRows) {
                final rId = r.isNotEmpty ? (r[0]?.toString() ?? '') : '';
                final rowName = r.length > 1 ? (r[1]?.toString() ?? '') : '';
                if (rId.isNotEmpty && (rId == modId || _normalizeKey(rowName) == _normalizeKey(name))) {
                  activated = true;
                  rowId = rId;
                  // Extract IDs from A:E row (id, name, dashboard, settings, tabs)
                  if (r.length > 2) extDashboardId = r[2]?.toString();
                  if (r.length > 3) extSettingsId = r[3]?.toString();
                  if (r.length > 4) extTabsId = r[4]?.toString();
                  break;
                }
              }
            }
          } catch (_) {}

          // If this module is deactivated for the current user, treat as not activated
          if (deactivated.contains(modId)) activated = false;

          // For activated modules, prefer the Drive folder ID as the primary 'id'
          // so memory/cache lookups resolve the provisioned schema correctly.
          final effectiveId = activated ? (rowId ?? modId) : modId;

          // Try to load detailed info (favoring local cache or Drive indirectly via sync)
          try {
            Map<String, dynamic>? config = await schemaProvider.service.getCachedConfig(effectiveId);
            
            // REMOVED: Asset fallback deleted per request. Only cache and Drive should be used.
            // if (config == null && !activated) { ... }

            if (config != null) {
              final settingsRaw = config['settings'] as Map<String, dynamic>?;
              if (settingsRaw != null) {
                name = settingsRaw['name']?['value']?.toString() ?? name;
                icon = settingsRaw['icon']?['value']?.toString() ?? icon;
                primaryColor = settingsRaw['primaryColor']?['value']?.toString() ?? primaryColor;
              }
              desc = config['desc']?.toString() ?? desc;
            }
          } catch (_) {}

          result.add({
            'id': effectiveId,
            'assetKey': modId,
            'name': name,
            'icon': icon,
            'desc': desc,
            'primaryColor': primaryColor,
            'activated': activated,
            'settingsSheetId': extSettingsId,
            'dashboardSheetId': extDashboardId,
            'tabsSheetId': extTabsId,
          });
        } catch (e) {
          debugPrint('Error loading enabled module entry "$rawKey": $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error loading enabled modules: $e');
    }
    return result;
  }

  String _normalizeKey(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // Icons are resolved via `iconFromName` in `lib/utils/icon_lookup.dart`.

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
          // If sync failed and not in cache, we just show error message or stay empty.
          // Fallback to Assets removed per request.
          setState(() {
            _errorMessage = "Unable to load module data. Please check your connection.";
          });
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
          debugPrint('Attempting direct read by provided sheet ids');
          final newConfig = <String, dynamic>{};

          // 1) Settings (required for authoritative config)
          try {
            debugPrint('Reading settings by id=${widget.settingsSheetId}');
            final settings = await driveService.readSettingsById(widget.settingsSheetId!);
            if (settings != null) newConfig['settings'] = settings;
          } catch (e) {
            debugPrint('Error reading settings by id: $e');
          }

          // 2) Dashboard (optional, but prefer explicit id)
          if (widget.dashboardSheetId != null && widget.dashboardSheetId!.isNotEmpty) {
            try {
              debugPrint('Reading dashboard by id=${widget.dashboardSheetId}');
              final dash = await driveService.readDashboardById(widget.dashboardSheetId!);
              if (dash != null) newConfig['dashboard'] = dash;
            } catch (e) {
              debugPrint('Error reading dashboard by id: $e');
            }
          }

          // 3) Tabs
          if (widget.tabsSheetId != null && widget.tabsSheetId!.isNotEmpty) {
            try {
              debugPrint('Reading tabs by id=${widget.tabsSheetId}');
              final tabs = await driveService.readTabsById(widget.tabsSheetId!);
              if (tabs != null) newConfig['tabs'] = tabs;
            } catch (e) {
              debugPrint('Error reading tabs by id: $e');
            }
          }

          if (newConfig.isNotEmpty) {
            debugPrint('Module ${widget.module.id} schema loaded directly from spreadsheets.');
            try {
              // Cache each part separately so each sheet's metadata can be tracked
              // and updated independently.
              if (newConfig.containsKey('settings') && widget.settingsSheetId != null && widget.settingsSheetId!.isNotEmpty) {
                try {
                  final settingsModified = await driveService.getFileModifiedTime(widget.settingsSheetId!);
                  await schemaService.cacheConfig(widget.module.id, {'settings': newConfig['settings']}, fileId: widget.settingsSheetId, modifiedTime: settingsModified?.toIso8601String());
                } catch (e) {
                  debugPrint('Error caching settings part: $e');
                }
              }

              if (newConfig.containsKey('dashboard') && widget.dashboardSheetId != null && widget.dashboardSheetId!.isNotEmpty) {
                try {
                  final dashModified = await driveService.getFileModifiedTime(widget.dashboardSheetId!);
                  await schemaService.cacheConfig(widget.module.id, {'dashboard': newConfig['dashboard']}, fileId: widget.dashboardSheetId, modifiedTime: dashModified?.toIso8601String());
                } catch (e) {
                  debugPrint('Error caching dashboard part: $e');
                }
              }

              if (newConfig.containsKey('tabs') && widget.tabsSheetId != null && widget.tabsSheetId!.isNotEmpty) {
                try {
                  final tabsModified = await driveService.getFileModifiedTime(widget.tabsSheetId!);
                  await schemaService.cacheConfig(widget.module.id, {'tabs': newConfig['tabs']}, fileId: widget.tabsSheetId, modifiedTime: tabsModified?.toIso8601String());
                } catch (e) {
                  debugPrint('Error caching tabs part: $e');
                }
              }
            } catch (e) {
              debugPrint('Error caching direct-read config: $e');
            }
            if (mounted) await _processJson(newConfig);
            return newConfig;
          }
        } catch (e) {
          debugPrint('Direct read by sheet ids failed: $e');
        }
      }

      final newJson = await schemaService.syncConfig(
        widget.module.id, 
        settingsId: widget.settingsSheetId,
        dashboardId: widget.dashboardSheetId,
        tabsId: widget.tabsSheetId,
      );
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

  Future<void> _processJson(Map<String, dynamic> jsonMap) async {
    if (!mounted) return;

    final schemaProvider = Provider.of<SchemaProvider>(context, listen: false);
    final driveProvider = Provider.of<DriveProvider>(context, listen: false);
    final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    final driveServiceFromProvider = driveProvider.driveService;
    
    try {
      _settingsSheetIds.clear();
      _dashboardSheetIds.clear();
      _tabsSheetIds.clear();

      if (widget.settingsSheetId != null) _settingsSheetIds[widget.module.id] = widget.settingsSheetId!;
      if (widget.dashboardSheetId != null) _dashboardSheetIds[widget.module.id] = widget.dashboardSheetId!;
      if (widget.tabsSheetId != null) _tabsSheetIds[widget.module.id] = widget.tabsSheetId!;

      final settingsRaw = jsonMap['settings'];
      final settingsMap = settingsRaw != null ? Map<String, dynamic>.from(settingsRaw as Map) : <String, dynamic>{};
      
      final name = settingsMap['name']?['value']?.toString() ?? jsonMap['name']?.toString() ?? widget.module.name;
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
      
      for (var i = 0; i < tabsList.length; i++) {
        final tab = Map<String, dynamic>.from(tabsList[i] as Map);
        if (tab['columns'] == null) tab['columns'] = [];
        final columns = List<dynamic>.from(tab['columns'] as List);
        for (var j = 0; j < columns.length; j++) {
          final col = columns[j];
          if (col is Map && col['options'] is String && (col['options'] as String).startsWith('settings.')) {
            final path = (col['options'] as String).split('.');
            if (path.length == 2) {
              final settingKey = path[1];
              final settingValue = settingsMap[settingKey]?['value'];
              final colMap = Map<String, dynamic>.from(col);
              colMap['options'] = settingValue is List ? settingValue : [];
              columns[j] = colMap;
            }
          }
        }
        tab['columns'] = columns;
        tabsList[i] = tab;
      }

      final tabs = tabsList.map((t) {
        try {
          return TabConfig.fromJson(t as Map<String, dynamic>);
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
            settingsItems[k] = SettingItem(label: k, type: 'list', value: v);
          } else if (v != null) {
            settingsItems[k] = SettingItem(label: k, type: 'text', value: v);
          }
        } catch (_) {}
      });

      try {
        final extensionsRaw = jsonMap['extensions'];
        if (extensionsRaw is List) {
          final exList = extensionsRaw.map((e) => e.toString()).toList();
          settingsItems['extensions'] = SettingItem(label: 'Extensions', type: 'list', value: exList);
        }
      } catch (_) {}

      final baseModuleSchema = ModuleSchema(
        id: widget.module.id,
        name: name,
        icon: icon,
        primaryColor: primaryColor,
        version: version,
        settings: settingsItems,
        dashboard: dashboard,
        tabs: tabs,
      );
      _baseModule = baseModuleSchema;

      final combinedTabs = <TabConfig>[];
      combinedTabs.addAll(tabs);
      _tabSourceModuleIds.clear();
      for (final baseTab in tabs) {
        _tabSourceModuleIds[baseTab.id] = widget.module.id;
      }

      final List<String> extensionKeys = [];
      final extSetting = settingsItems['extensions'];
      if (extSetting != null && extSetting.value is List) {
        extensionKeys.addAll((extSetting.value as List).map((e) => e.toString()));
      }

      final installedIds = <String>{};
      final Map<String, String> normalizedKeyToId = {};
      try {
        final driveService = driveServiceFromProvider;
        if (driveService != null) {
          String? uaId = workspaceProvider.lastUserAccessSpreadsheetId;
          if (uaId == null || uaId.isEmpty) uaId = await WorkspaceProvider.getLastUserAccessSpreadsheetId();
          if (uaId != null && uaId.isNotEmpty) {
            final resp = await driveService.sheetsApi.spreadsheets.values.get(uaId, 'modules!A1:Z');
            final all = resp.values ?? [];
            if (all.isNotEmpty) {
              final rows = all.length > 1 ? all.sublist(1) : [];
              for (var row in rows) {
                final r = List<dynamic>.from(row as List);
                final rowId = r.isNotEmpty ? (r[0]?.toString() ?? '') : '';
                final rowName = r.length > 1 ? (r[1]?.toString() ?? '') : '';
                if (rowId.isNotEmpty) {
                  final normalizedRowId = _normalizeKey(rowId);
                  installedIds.add(normalizedRowId);
                  normalizedKeyToId[normalizedRowId] = rowId;
                  if (r.length > 2 && r[2]?.toString().isNotEmpty == true) _dashboardSheetIds[rowId] = r[2]!.toString();
                  if (r.length > 3 && r[3]?.toString().isNotEmpty == true) _settingsSheetIds[rowId] = r[3]!.toString();
                  if (r.length > 4 && r[4]?.toString().isNotEmpty == true) _tabsSheetIds[rowId] = r[4]!.toString();
                }
                if (rowName.isNotEmpty) {
                  final normalizedRowName = _normalizeKey(rowName);
                  installedIds.add(normalizedRowName);
                  normalizedKeyToId[normalizedRowName] = rowId;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Could not determine installed modules: $e');
      }

      for (final otherModuleId in extensionKeys) {
        try {
          final String normalizedKey = _normalizeKey(otherModuleId);
          final String resolvedOtherId = normalizedKeyToId[normalizedKey] ?? otherModuleId;
          ModuleSchema? otherModule = schemaProvider.getFromMemory(resolvedOtherId);
          Map<String, dynamic>? otherJson;
          
          if (otherModule == null) {
            otherJson = await schemaProvider.service.getCachedConfig(resolvedOtherId);
            // If not cached yet, sync directly from Drive using the known sheet IDs.
            if (otherJson == null) {
              final schemaService = Provider.of<SchemaProvider>(context, listen: false).service;
              try {
                otherJson = await schemaService.syncConfig(
                  resolvedOtherId,
                  settingsId: _settingsSheetIds[resolvedOtherId],
                  dashboardId: _dashboardSheetIds[resolvedOtherId],
                  tabsId: _tabsSheetIds[resolvedOtherId],
                );
              } catch (_) {}
                        }
            // No asset fallback here; extensions that are active MUST have a config in cache or drive.
          }

          if (otherModule == null && otherJson != null) {
            final otherSettingsRaw = otherJson['settings'] is Map ? Map<String, dynamic>.from(otherJson['settings'] as Map) : <String, dynamic>{};
            final candidateName = (otherSettingsRaw['name']?['value']?.toString() ?? otherModuleId);
            final normalizedResolvedId = _normalizeKey(resolvedOtherId);
            if (!installedIds.contains(normalizedResolvedId) && !installedIds.contains(normalizedKey)) {
              continue;
            }

            final otherTabsRaw = otherJson['tabs'];
            final otherTabsList = otherTabsRaw is List ? List<dynamic>.from(otherTabsRaw) : [];
            final processedOtherTabs = <TabConfig>[];

            for (var tRaw in otherTabsList) {
              if (tRaw is! Map) continue;
              final tabMap = Map<String, dynamic>.from(tRaw);
              if (tabMap['columns'] is List) {
                final cols = List<dynamic>.from(tabMap['columns'] as List);
                for (var j = 0; j < cols.length; j++) {
                  final col = cols[j];
                  if (col is Map && col['options'] is String && (col['options'] as String).startsWith('settings.')) {
                    final key = (col['options'] as String).split('.').last;
                    final val = otherSettingsRaw[key]?['value'];
                    final colMap = Map<String, dynamic>.from(col);
                    colMap['options'] = val is List ? val : [];
                    cols[j] = colMap;
                  }
                }
                tabMap['columns'] = cols;
              }
              try {
                processedOtherTabs.add(TabConfig.fromJson(tabMap));
              } catch (_) {}
            }

            final authoritativeId = otherSettingsRaw['id']?['value']?.toString() ?? otherModuleId;
            final moduleIdForCache = normalizedKeyToId[_normalizeKey(candidateName)]
              ?? normalizedKeyToId[normalizedKey]
              ?? authoritativeId;

            for (var ot in processedOtherTabs) {
              final newId = authoritativeId == ot.id ? ot.id : '${authoritativeId}_${ot.id}';
              combinedTabs.add(ot.copyWith(id: newId));
              _tabSourceModuleIds[newId] = moduleIdForCache;
            }

            final otherSettingsItems = <String, SettingItem>{};
            otherSettingsRaw.forEach((k, v) {
              try {
                if (v is Map) {
                  otherSettingsItems[k] = SettingItem.fromJson(Map<String, dynamic>.from(v));
                } else if (v is List) {
                  otherSettingsItems[k] = SettingItem(label: k, type: 'list', value: v);
                } else if (v != null) {
                  otherSettingsItems[k] = SettingItem(label: k, type: 'text', value: v);
                }
              } catch (_) {}
            });

            final otherModuleSchema = ModuleSchema(
              id: moduleIdForCache,
              name: otherSettingsRaw['name']?['value']?.toString() ?? otherModuleId,
              icon: otherSettingsRaw['icon']?['value']?.toString() ?? '',
              primaryColor: otherSettingsRaw['primaryColor']?['value']?.toString() ?? '#2196F3',
              version: otherSettingsRaw['version']?['value']?.toString() ?? '1.0',
              settings: otherSettingsItems,
              dashboard: otherJson['dashboard'] != null ? DashboardConfig.fromJson(Map<String, dynamic>.from(otherJson['dashboard'] as Map)) : DashboardConfig(cards: []),
              tabs: processedOtherTabs,
            );
            
            schemaProvider.updateMemoryCache(moduleIdForCache, otherModuleSchema);
            await schemaProvider.service.cacheConfig(moduleIdForCache, otherJson);
          } else if (otherModule != null) {
            for (var ot in otherModule.tabs) {
              final newId = otherModule.id == ot.id ? ot.id : '${otherModule.id}_${ot.id}';
              combinedTabs.add(ot.copyWith(id: newId));
              _tabSourceModuleIds[newId] = otherModule.id;
            }
          }
        } catch (e) {
          debugPrint('Error merging extension $otherModuleId: $e');
        }
      }

      final mergedModuleResult = ModuleSchema(
        id: baseModuleSchema.id,
        name: baseModuleSchema.name,
        icon: baseModuleSchema.icon,
        primaryColor: baseModuleSchema.primaryColor,
        version: baseModuleSchema.version,
        settings: baseModuleSchema.settings,
        dashboard: baseModuleSchema.dashboard,
        tabs: combinedTabs,
      );

      schemaProvider.updateMemoryCache(widget.module.id, mergedModuleResult);

      if (mounted) {
        setState(() {
          _fullModule = mergedModuleResult;
        });
      }
    } catch (e) {
      debugPrint('Error in _processJson: $e');
      if (mounted) {
        setState(() {
          _errorMessage = "Error parsing blueprint: $e";
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
                  MaterialPageRoute(builder: (context) => SchemaEditorScreen(
                    module: _baseModule ?? cachedModule ?? widget.module,
                    settingsSheetId: widget.settingsSheetId,
                    dashboardSheetId: widget.dashboardSheetId,
                    tabsSheetId: widget.tabsSheetId,
                  )),
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
                      final provider = Provider.of<SchemaProvider>(context, listen: false);
                      final resolvedSourceId = _tabSourceModuleIds[t.id];
                      if (resolvedSourceId != null) {
                        sourceModule = provider.getFromMemory(resolvedSourceId) ?? sourceModule;
                      }

                      if (sourceModule == module) {
                        final parts = t.id.split('_');
                        if (parts.length > 1) {
                          final prefix = parts[0];
                          final candidate = provider.getFromMemory(prefix);
                          if (candidate != null) {
                            sourceModule = candidate;
                          }
                        }
                      }

                      // If still unresolved (common when tab id is just 'tickets'),
                      // search cached modules to find one that contains this tab id.
                      if (sourceModule == module) {
                        final byTab = provider.findModuleByTabId(t.id);
                        if (byTab != null) sourceModule = byTab;
                      }
                    } catch (_) {}

                    return ModuleTabScreen(
                      tab: t,
                      primaryColor: primaryColor,
                      settings: sourceModule.settings,
                      module: sourceModule,
                      settingsSheetId: _settingsSheetIds[sourceModule.id] ?? widget.settingsSheetId,
                      dashboardSheetId: _dashboardSheetIds[sourceModule.id] ?? widget.dashboardSheetId,
                      tabsSheetId: _tabsSheetIds[sourceModule.id] ?? widget.tabsSheetId,
                      sourceModuleId: _tabSourceModuleIds[t.id] ?? sourceModule.id,
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
