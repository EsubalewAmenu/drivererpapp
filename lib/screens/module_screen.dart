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

class ModuleScreen extends StatefulWidget {
  final ModuleSchema module;

  const ModuleScreen({super.key, required this.module});

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

  Future<void> _loadSchema() async {
    debugPrint('ModuleScreen: Starting _loadSchema for ${widget.module.id}');
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
            final jsonString = await rootBundle.loadString('assets/erp_modules/$fileName.json');
            assetJson = jsonDecode(jsonString);
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
        if (v != null && v is Map<String, dynamic>) {
          try {
            settingsItems[k] = SettingItem.fromJson(v);
          } catch (e) {
            debugPrint('Error parsing setting $k: $e');
          }
        }
      });

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

      // If settings enable other modules, load their tabs and append
      final combinedTabs = <TabConfig>[];
      combinedTabs.addAll(tabs);

      for (final entry in settingsItems.entries) {
        final key = entry.key;
        final setting = entry.value;
        if (key.startsWith('enable_') && (setting.value is bool) && (setting.value == true)) {
          final otherModuleId = key.substring('enable_'.length);
          try {
            ModuleSchema? otherModule = Provider.of<SchemaProvider>(context, listen: false).getFromMemory(otherModuleId);
            Map<String, dynamic>? otherJson;
            if (otherModule == null) {
              // Try to load from assets by module id/name
              try {
                final jsonString = await rootBundle.loadString('assets/erp_modules/${otherModuleId.toLowerCase()}.json');
                otherJson = jsonDecode(jsonString) as Map<String, dynamic>;
              } catch (_) {
                otherJson = null;
              }

              if (otherJson != null) {
                // Parse the other module's tabs similarly to above
                final otherSettingsRaw = otherJson['settings'];
                final otherSettingsMap = otherSettingsRaw != null ? Map<String, dynamic>.from(otherSettingsRaw as Map) : <String, dynamic>{};
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

                // Prefix ids to avoid collisions and mark origin
                for (var ot in parsedOtherTabs) {
                  final newId = '${otherModuleId}_${ot.id}';
                  combinedTabs.add(ot.copyWith(id: newId));
                }
              }
            } else {
              // Append tabs from loaded otherModule
              for (var ot in otherModule.tabs) {
                final newId = '${otherModuleId}_${ot.id}';
                combinedTabs.add(ot.copyWith(id: newId));
              }
            }
          } catch (e) {
            debugPrint('Error loading enabled module $otherModuleId: $e');
          }
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
      length: (module.tabs.length) + 1, // +1 for Dashboard
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
                  String fileName;
                  if (index == 0) {
                    fileName = 'config';
                  } else {
                    fileName = module.tabs[index - 1].id;
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
                  MaterialPageRoute(builder: (context) => SchemaEditorScreen(module: _baseModule ?? widget.module)),
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
                    // Determine source module for this tab if prefixed like '{moduleId}_tabid'
                    ModuleSchema sourceModule = module;
                    try {
                      final parts = t.id.split('_');
                      if (parts.length > 1) {
                        final prefix = parts[0];
                        final candidate = Provider.of<SchemaProvider>(context, listen: false).getFromMemory(prefix);
                        if (candidate != null) sourceModule = candidate;
                      }
                    } catch (_) {}

                    return ModuleTabScreen(
                      tab: t,
                      primaryColor: primaryColor,
                      settings: sourceModule.settings,
                      module: sourceModule,
                    );
                  }),
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
