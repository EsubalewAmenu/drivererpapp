import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schema_models.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../theme/app_theme.dart';
import 'schema_editor_screen.dart';
import 'module/module_dashboard.dart';
import 'module/module_tab_screen.dart';

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
      final authService = Provider.of<AuthService>(context, listen: false);
      final driveService = DriveService(authService.authClient!);
      
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
          print('Asset not found for $fileName, using default empty schema');
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

      setState(() {
        _fullModule = loadedModule;
        _isLoadingSchema = false;
      });

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
      print('Error loading module schema: $e');
      setState(() {
        _fullModule = widget.module;
        _isLoadingSchema = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSchema) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final module = _fullModule ?? widget.module;
    final primaryColor = Color(int.parse(module.primaryColor.replaceAll('#', '0xFF')));

    return DefaultTabController(
      length: module.tabs.length + 1, // +1 for Dashboard
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            module.name.toUpperCase(),
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
          centerTitle: true,
          backgroundColor: AppTheme.backgroundColor,
          actions: [
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
            unselectedLabelColor: AppTheme.secondaryTextColor,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
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
