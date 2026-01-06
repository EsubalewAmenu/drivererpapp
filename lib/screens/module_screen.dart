import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../providers/drive_provider.dart';
import '../theme/app_theme.dart';
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
  bool _isLoadingSchema = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchema();
    });
  }

  Future<void> _loadSchema() async {
    try {
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService!;
      
      // 1. Check for config (Sheet) in the module folder
      String? configFileId = await driveService.getFileId(widget.module.id, 'config');
      
      Map<String, dynamic> jsonMap;
      bool isLocalConfig = false;

      if (configFileId != null) {
        // 2. Load from Drive Sheet
        jsonMap = await driveService.readModuleConfig(configFileId);
      } else {
        // 3. Load from Assets (Fallback)
        isLocalConfig = true;
        final fileName = widget.module.name.toLowerCase();
        // Handle case where asset might not exist (though it should for known modules)
        try {
          final jsonString = await rootBundle.loadString('assets/erp_modules/$fileName.json');
          jsonMap = jsonDecode(jsonString);
        } catch (e) {
          debugPrint('Asset not found for $fileName, using default empty schema');
          jsonMap = {
            'settings': {'name': {'value': widget.module.name}},
            'dashboard': {'kpiCards': []},
            'tabs': []
          };
        }
      }
      
      // Parse JSON to ModuleSchema
      final settingsMap = (jsonMap['settings'] as Map<String, dynamic>?) ?? {};
      final name = settingsMap['name']?['value'] ?? widget.module.name;
      
      // Extract core properties from settings if available, otherwise fallback to root or widget defaults
      final icon = settingsMap['icon']?['value'] ?? jsonMap['icon'] ?? widget.module.icon;
      final primaryColor = settingsMap['primaryColor']?['value'] ?? jsonMap['primaryColor'] ?? widget.module.primaryColor;
      final version = settingsMap['version']?['value'] ?? jsonMap['version'] ?? widget.module.version;
      
      final dashboard = jsonMap['dashboard'] != null 
          ? DashboardConfig.fromJson(jsonMap['dashboard'])
          : DashboardConfig(kpiCards: []);
      
      final tabsList = (jsonMap['tabs'] as List?) ?? [];
      
      // Pre-process tabs (same logic as before)
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

      final tabs = tabsList.map((t) => TabConfig.fromJson(t)).toList();
      final settingsItems = settingsMap.map((k, v) => MapEntry(k, SettingItem.fromJson(v)));

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

      if (mounted) {
        setState(() {
          _fullModule = loadedModule;
          _isLoadingSchema = false;
        });
      }

      // 4. If local config, navigate to Editor to complete setup
      if (isLocalConfig && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SchemaEditorScreen(
              module: loadedModule,
              isNewSetup: true,
            ),
          ),
        ).then((_) {
          // Reload schema after returning from editor (in case it was saved)
          _loadSchema();
        });
      }

    } catch (e) {
      debugPrint('Error loading module schema: $e');
      if (mounted) {
        setState(() {
          _fullModule = widget.module;
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
    if (_isLoadingSchema) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final module = _fullModule ?? widget.module;
    final primaryColor = Color(int.parse(module.primaryColor.replaceAll('#', '0xFF')));
    final theme = Theme.of(context);

    return DefaultTabController(
      length: module.tabs.length + 1, // +1 for Dashboard
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
                );
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
        body: TabBarView(
          children: [
            ModuleDashboard(
              key: UniqueKey(), // Force rebuild when tab changes or parent rebuilds
              module: module, 
              primaryColor: primaryColor
            ),
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
}
