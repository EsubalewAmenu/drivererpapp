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
  bool _isLoadingSchema = false;

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
        _processJson(cachedJson);
        
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
            debugPrint('Asset not found for $fileName');
            assetJson = {
              'settings': {'name': {'value': widget.module.name}},
              'dashboard': {'cards': []},
              'tabs': []
            };
          }
          _processJson(assetJson, isAssetFallback: true);
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
        _processJson(newJson);
      }
      return newJson;
    } catch (e) {
      debugPrint('Sync error: $e');
      return null;
    }
  }

  void _processJson(Map<String, dynamic> jsonMap, {bool isAssetFallback = false}) {
    if (!mounted) return;
    
    // Parse JSON to ModuleSchema
    final settingsMap = (jsonMap['settings'] as Map<String, dynamic>?) ?? {};
    final name = settingsMap['name']?['value'] ?? widget.module.name;
    
    final icon = settingsMap['icon']?['value'] ?? jsonMap['icon'] ?? widget.module.icon;
    final primaryColor = settingsMap['primaryColor']?['value'] ?? jsonMap['primaryColor'] ?? widget.module.primaryColor;
    final version = settingsMap['version']?['value'] ?? jsonMap['version'] ?? widget.module.version;
    
    final dashboard = jsonMap['dashboard'] != null 
        ? DashboardConfig.fromJson(jsonMap['dashboard'])
        : DashboardConfig(cards: []);
    
    final tabsList = (jsonMap['tabs'] as List?) ?? [];
    
    // Pre-process tabs
    for (var tab in tabsList) {
      if (tab['columns'] != null) {
        for (var col in tab['columns']) {
          if (col['options'] is String && (col['options'] as String).startsWith('settings.')) {
            final path = (col['options'] as String).split('.');
            if (path.length == 2) {
              final settingKey = path[1];
              final settingValue = settingsMap[settingKey]?['value'];
              if (settingValue is List) {
                col['options'] = settingValue;
              } else {
                col['options'] = [];
              }
            }
          }
        }
      }
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
      if (v != null) {
        try {
          settingsItems[k] = SettingItem.fromJson(v as Map<String, dynamic>);
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

    // Update memory cache for instant access next time
    Provider.of<SchemaProvider>(context, listen: false).updateMemoryCache(widget.module.id, loadedModule);

    setState(() {
      _fullModule = loadedModule;
      _isLoadingSchema = false;
    });

    // If it was an asset fallback, navigate to Editor
    if (isAssetFallback) {
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
                  MaterialPageRoute(builder: (context) => SchemaEditorScreen(module: module)),
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
        body: (module.tabs.isEmpty && _fullModule == null)
            ? _buildInitialLoadingBody(theme)
            : TabBarView(
                children: [
                  ModuleDashboard(module: module, primaryColor: primaryColor),
                  ...module.tabs.map((t) => ModuleTabScreen(
                    tab: t, 
                    primaryColor: primaryColor,
                    settings: module.settings,
                    module: module,
                  )),
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
}
