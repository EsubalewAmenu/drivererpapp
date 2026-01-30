import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schema_models.dart';
import 'drive_service.dart';

class SchemaService {
  static const String _cachePrefix = 'module_config_';
  static const String _metaPrefix = 'module_meta_';
  static const String _settingsSuffix = '_settings';
  static const String _dashboardSuffix = '_dashboard';
  static const String _tabsSuffix = '_tabs';

  final DriveService? driveService;
  final String? userEmail;

  SchemaService({this.driveService, this.userEmail});

  /// Loads the module configuration from local cache if available.
  Future<Map<String, dynamic>?> getCachedConfig(String moduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsStr = prefs.getString('$_cachePrefix${moduleId}$_settingsSuffix');
      final dashboardStr = prefs.getString('$_cachePrefix${moduleId}$_dashboardSuffix');
      final tabsStr = prefs.getString('$_cachePrefix${moduleId}$_tabsSuffix');

      if (settingsStr == null && dashboardStr == null && tabsStr == null) return null;

      final result = <String, dynamic>{};
      if (settingsStr != null) {
        try {
          result['settings'] = Map<String, dynamic>.from(jsonDecode(settingsStr) as Map);
        } catch (_) {}
      }
      if (dashboardStr != null) {
        try {
          result['dashboard'] = jsonDecode(dashboardStr);
        } catch (_) {}
      }
      if (tabsStr != null) {
        try {
          result['tabs'] = jsonDecode(tabsStr);
        } catch (_) {}
      }

      return result;
    } catch (e) {
      debugPrint('Error loading cached config: $e');
    }
    return null;
  }

  /// Saves the module configuration to local cache.
  Future<void> cacheConfig(String moduleId, Map<String, dynamic> config,
      {String? fileId, String? modifiedTime}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (config.containsKey('settings')) {
        try {
          await prefs.setString('$_cachePrefix${moduleId}$_settingsSuffix', jsonEncode(config['settings']));
          debugPrint('SchemaService: cached settings for module=$moduleId');
        } catch (_) {}
      }

      if (config.containsKey('dashboard')) {
        try {
          await prefs.setString('$_cachePrefix${moduleId}$_dashboardSuffix', jsonEncode(config['dashboard']));
          debugPrint('SchemaService: cached dashboard for module=$moduleId');
        } catch (_) {}
      }

      if (config.containsKey('tabs')) {
        try {
          await prefs.setString('$_cachePrefix${moduleId}$_tabsSuffix', jsonEncode(config['tabs']));
          debugPrint('SchemaService: cached tabs for module=$moduleId (count=${(config['tabs'] as List?)?.length ?? 0})');
        } catch (_) {}
      }

      if (fileId != null && modifiedTime != null) {
        final meta = {
          'fileId': fileId,
          'modifiedTime': modifiedTime,
        };
        await prefs.setString('$_metaPrefix$moduleId', jsonEncode(meta));
        debugPrint('SchemaService: cached meta for module=$moduleId fileId=$fileId modifiedTime=$modifiedTime');
      }
    } catch (e) {
      debugPrint('Error caching config: $e');
    }
  }

  /// Removes a cached module configuration and its metadata.
  Future<void> removeCachedConfig(String moduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix${moduleId}$_settingsSuffix');
      await prefs.remove('$_cachePrefix${moduleId}$_dashboardSuffix');
      await prefs.remove('$_cachePrefix${moduleId}$_tabsSuffix');
      await prefs.remove('$_metaPrefix$moduleId');
    } catch (e) {
      debugPrint('Error removing cached config: $e');
    }
  }

  /// Gets the cached metadata for a module.
  Future<Map<String, String>?> getCachedMeta(String moduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString('$_metaPrefix$moduleId');
      if (metaJson != null) {
        return Map<String, String>.from(jsonDecode(metaJson));
      }
    } catch (e) {
      debugPrint('Error loading cached meta: $e');
    }
    return null;
  }

  /// Checks if the remote configuration has changed and returns the new config if it has.
  /// Strictly looks for a user-specific settings spreadsheet named '<userEmail>_settings'
  /// inside the module's 'config' folder. Returns null if no update is needed or on error.
  Future<Map<String, dynamic>?> syncConfig(String moduleId, {String? settingsId}) async {
    if (driveService == null) return null;

    try {
      String? configFileId = settingsId;
      if (configFileId == null || configFileId.isEmpty) {
        if (userEmail == null) {
          debugPrint('No userEmail provided; strict user-specific config lookup skipped');
          return null;
        }

        final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
        final settingsName = '${userEmail}_settings';
        configFileId = await driveService!.getFileId(configFolderId, settingsName);
      }

      if (configFileId == null || configFileId.isEmpty) {
        debugPrint('User-specific settings file not found for module $moduleId');
        return null; // strict: do not fallback
      }

      final remoteModifiedTime = await driveService!.getFileModifiedTime(configFileId);
      final remoteModifiedString = remoteModifiedTime?.toIso8601String();

      final localMeta = await getCachedMeta(moduleId);
      if (localMeta != null &&
          localMeta['fileId'] == configFileId &&
          localMeta['modifiedTime'] == remoteModifiedString) {
        debugPrint('Module $moduleId config is up to date.');
        return null;
      }

      debugPrint('Syncing module $moduleId config from Drive...');
      final newConfig = await driveService!.readModuleConfig(configFileId);

      if (newConfig == null) {
        debugPrint('Remote config for $moduleId was null or malformed.');
        return null;
      }

      await cacheConfig(moduleId, newConfig, fileId: configFileId, modifiedTime: remoteModifiedString);
      return newConfig;
    } catch (e) {
      debugPrint('Error syncing module config: $e');
      return null;
    }
  }

  /// Saves the module configuration to Drive and updates the local cache.
  Future<void> saveModuleConfig(String moduleId, ModuleSchema config) async {
    if (driveService == null) throw Exception('DriveService not initialized');

    try {
      String? fileId;

      if (userEmail != null) {
        final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
        final fileName = '${userEmail}_settings';

        fileId = await driveService!.getFileId(configFolderId, fileName);

        final configMap = config.toJson();

        try {
          if (config.settings.containsKey('extensions')) {
            final ext = config.settings['extensions']?.value;
            if (ext is List) {
              configMap['extensions'] = ext;
            }
          }
        } catch (_) {}

        if (fileId != null) {
          await driveService!.updateModuleConfig(fileId, configMap);
        } else {
          fileId = await driveService!.createModuleConfig(configFolderId, fileName, configMap);
        }

        try {
          String companyFolderId = moduleId;
          try {
            final file = await driveService!.driveApi.files.get(moduleId, $fields: 'parents') as dynamic;
            final parents = (file.parents as List?) ?? [];
            if (parents.isNotEmpty) companyFolderId = parents.first as String;
          } catch (_) {}

          final userAccessFolderId = await driveService!.ensureUserAccessFolder(companyFolderId);
          final userAccessFileId = await driveService!.ensureUserAccessSpreadsheet(userAccessFolderId, userEmail!);

          final dashboardId = await driveService!.getFileId(configFolderId, '${userEmail}_dashboard');
          final tabsId = await driveService!.getFileId(configFolderId, '${userEmail}_tabs');

          await driveService!.upsertUserAccessModule(
            userAccessFileId,
            moduleId,
            config.name,
            dashboardId ?? '',
            fileId,
            tabsId ?? '',
          );
        } catch (e) {
          debugPrint('Error updating user access spreadsheet: $e');
        }
      } else {
        throw Exception('userEmail is required to save module config; legacy fallback disabled');
      }

      final modifiedTime = await driveService!.getFileModifiedTime(fileId!);
      if (modifiedTime != null) {
        await cacheConfig(moduleId, config.toJson(), fileId: fileId, modifiedTime: modifiedTime.toIso8601String());
      } else {
        await cacheConfig(moduleId, config.toJson());
      }
    } catch (e) {
      debugPrint('Error saving module config: $e');
      rethrow;
    }
  }

  /// Save only the settings portion of a module to the per-user settings spreadsheet.
  Future<void> saveSettingsPart(String moduleId, Map<String, dynamic> settings, {String? settingsId}) async {
    if (driveService == null) throw Exception('DriveService not initialized');
    
    if (settingsId != null && settingsId.isNotEmpty) {
      await driveService!.writeSettingsById(settingsId, settings);
      final modifiedTime = await driveService!.getFileModifiedTime(settingsId);
      await cacheConfig(moduleId, {'settings': settings}, fileId: settingsId, modifiedTime: modifiedTime?.toIso8601String());
      return;
    }

    if (userEmail == null) throw Exception('userEmail required for resolution');

    final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
    final fileName = '${userEmail}_settings';
    // ... rest of the settings fallback ...

    String? resolvedSettingsId = await driveService!.getFileId(configFolderId, fileName);
    if (resolvedSettingsId == null) {
      // Create full config spreadsheets with initial settings
      final createdId = await driveService!.createModuleConfig(configFolderId, fileName, {'settings': settings});
      resolvedSettingsId = createdId;
    } else {
      await driveService!.writeSettingsById(resolvedSettingsId, settings);
    }

    final modifiedTime = await driveService!.getFileModifiedTime(resolvedSettingsId);
    await cacheConfig(moduleId, {'settings': settings}, fileId: resolvedSettingsId, modifiedTime: modifiedTime?.toIso8601String());
  }

  /// Save only the dashboard/cards portion to the dashboard spreadsheet.
  Future<void> saveDashboardPart(String moduleId, dynamic dashboard, {String? settingsId, String? dashboardId}) async {
    if (driveService == null) throw Exception('DriveService not initialized');

    // If caller provided a direct dashboard spreadsheet id, write straight to it
    if (dashboardId != null && dashboardId.isNotEmpty) {
      await driveService!.writeDashboardById(dashboardId, dashboard);
      // Prefer caching against provided settingsId if available
      final cacheFileId = (settingsId != null && settingsId.isNotEmpty) ? settingsId : null;
      if (cacheFileId != null) {
        final modifiedTime = await driveService!.getFileModifiedTime(cacheFileId);
        await cacheConfig(moduleId, {'dashboard': dashboard}, fileId: cacheFileId, modifiedTime: modifiedTime?.toIso8601String());
      }
      return;
    }

    if (userEmail == null) throw Exception('userEmail required for resolution');

    // Fallback behavior when no explicit dashboardId provided: use existing meta/create as before
    final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
    final settingsName = '${userEmail}_settings';
    String? resolvedSettingsId = settingsId ?? await driveService!.getFileId(configFolderId, settingsName);
    if (resolvedSettingsId == null) {
      // create full config and let createModuleConfig handle dashboard
      final createdId = await driveService!.createModuleConfig(configFolderId, settingsName, {'dashboard': dashboard});
      final modifiedTime = await driveService!.getFileModifiedTime(createdId);
      await cacheConfig(moduleId, {'dashboard': dashboard}, fileId: createdId, modifiedTime: modifiedTime?.toIso8601String());
      return;
    }

    final meta = await driveService!.readMetaBySettingsId(resolvedSettingsId);
    String? resolvedDashboardId = meta['dashboard_id'];

    if (resolvedDashboardId == null || resolvedDashboardId.isEmpty) {
      resolvedDashboardId = await driveService!.createSpreadsheetInFolder(configFolderId, '${userEmail}_dashboard');
      meta['dashboard_id'] = resolvedDashboardId;
      await driveService!.writeMetaBySettingsId(resolvedSettingsId, meta);
    }

    await driveService!.writeDashboardById(resolvedDashboardId, dashboard);

    final modifiedTime = await driveService!.getFileModifiedTime(resolvedSettingsId);
    await cacheConfig(moduleId, {'dashboard': dashboard}, fileId: resolvedSettingsId, modifiedTime: modifiedTime?.toIso8601String());
  }

  /// Save only the tabs portion to the tabs spreadsheet.
  Future<void> saveTabsPart(String moduleId, List<dynamic> tabs, {String? settingsId, String? tabsId}) async {
    if (driveService == null) throw Exception('DriveService not initialized');

    // If caller provided direct tabs spreadsheet id, write straight to it
    if (tabsId != null && tabsId.isNotEmpty) {
      await driveService!.writeTabsById(tabsId, tabs);
      final cacheFileId = (settingsId != null && settingsId.isNotEmpty) ? settingsId : null;
      if (cacheFileId != null) {
        final modifiedTime = await driveService!.getFileModifiedTime(cacheFileId);
        await cacheConfig(moduleId, {'tabs': tabs}, fileId: cacheFileId, modifiedTime: modifiedTime?.toIso8601String());
      }
      return;
    }

    if (userEmail == null) throw Exception('userEmail required for resolution');

    // Fallback when no explicit tabsId provided
    final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
    final settingsName = '${userEmail}_settings';
    String? resolvedSettingsId = settingsId ?? await driveService!.getFileId(configFolderId, settingsName);
    if (resolvedSettingsId == null) {
      final createdId = await driveService!.createModuleConfig(configFolderId, settingsName, {'tabs': tabs});
      final modifiedTime = await driveService!.getFileModifiedTime(createdId);
      await cacheConfig(moduleId, {'tabs': tabs}, fileId: createdId, modifiedTime: modifiedTime?.toIso8601String());
      return;
    }

    final meta = await driveService!.readMetaBySettingsId(resolvedSettingsId);
    String? resolvedTabsId = meta['tabs_id'];

    if (resolvedTabsId == null || resolvedTabsId.isEmpty) {
      resolvedTabsId = await driveService!.createSpreadsheetInFolder(configFolderId, '${userEmail}_tabs');
      meta['tabs_id'] = resolvedTabsId;
      await driveService!.writeMetaBySettingsId(resolvedSettingsId, meta);
    }

    await driveService!.writeTabsById(resolvedTabsId, tabs);

    final modifiedTime = await driveService!.getFileModifiedTime(resolvedSettingsId);
    await cacheConfig(moduleId, {'tabs': tabs}, fileId: resolvedSettingsId, modifiedTime: modifiedTime?.toIso8601String());
  }

  /// Update a single field in a specific tab's configuration row-by-row in Drive.
  Future<void> saveTabField(String moduleId, String tabId, String key, dynamic value, {String? settingsId, String? tabsId}) async {
    if (driveService == null) throw Exception('DriveService not initialized');

    String? resolvedTabsId = tabsId;
    if (resolvedTabsId == null || resolvedTabsId.isEmpty) {
      if (userEmail == null) throw Exception('userEmail required for resolution');
      final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
      final settingsName = '${userEmail}_settings';
      final sId = settingsId ?? await driveService!.getFileId(configFolderId, settingsName);
      if (sId != null) {
        final meta = await driveService!.readMetaBySettingsId(sId);
        resolvedTabsId = meta['tabs_id'];
      }
    }

    if (resolvedTabsId != null && resolvedTabsId.isNotEmpty) {
      await driveService!.updateTabField(resolvedTabsId, tabId, key, value);
    } else {
      debugPrint('SchemaService: Could not resolve tabsId to update field $key for tab $tabId');
    }
  }

  /// Update multiple fields in a specific tab's configuration row-by-row in Drive.
  Future<void> saveTabFields(String moduleId, String tabId, Map<String, dynamic> fields, {String? settingsId, String? tabsId}) async {
    if (driveService == null) throw Exception('DriveService not initialized');

    String? resolvedTabsId = tabsId;
    if (resolvedTabsId == null || resolvedTabsId.isEmpty) {
      if (userEmail == null) throw Exception('userEmail required for resolution');
      final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
      final settingsName = '${userEmail}_settings';
      final sId = settingsId ?? await driveService!.getFileId(configFolderId, settingsName);
      if (sId != null) {
        final meta = await driveService!.readMetaBySettingsId(sId);
        resolvedTabsId = meta['tabs_id'];
      }
    }

    if (resolvedTabsId != null && resolvedTabsId.isNotEmpty) {
      await driveService!.updateTabFields(resolvedTabsId, tabId, fields);
    } else {
      debugPrint('SchemaService: Could not resolve tabsId to update fields for tab $tabId');
    }
  }

  Future<List<ModuleSchema>> loadModules() async {
    final moduleFiles = ['inventory.json'];
    final List<ModuleSchema> modules = [];

    for (final file in moduleFiles) {
      try {
        final String jsonString = await rootBundle.loadString('assets/erp_modules/$file');
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        modules.add(ModuleSchema.fromJson(jsonMap));
      } catch (e) {
        debugPrint('Error loading module $file: $e');
      }
    }

    return modules;
  }

  /// Attempts to load a module JSON asset by trying multiple filename variants.
  /// Returns the raw JSON string if found, or null if none of the candidates exist.
  static Future<String?> tryLoadModuleAsset(String key, {AssetBundle? bundle}) async {
    final bundleToUse = bundle ?? rootBundle;
    try {
      final lookupKey = key.toLowerCase().trim();

      final mapStr = await bundleToUse.loadString('assets/erp_modules/module_asset_map.json');
      final Map<String, dynamic> mapJson = jsonDecode(mapStr) as Map<String, dynamic>;

      final normalizedMap = <String, String>{};
      for (final entry in mapJson.entries) {
        final k = entry.key.toString().toLowerCase().trim();
        final v = entry.value?.toString() ?? '';
        if (v.isNotEmpty) normalizedMap[k] = v;
      }

      final mapped = normalizedMap[lookupKey];
      if (mapped != null && mapped.isNotEmpty) {
        try {
          return await bundleToUse.loadString('assets/erp_modules/$mapped');
        } catch (e) {
          debugPrint('Mapped asset found but failed to load $mapped: $e');
          return null;
        }
      }
    } catch (e) {
      debugPrint('Error trying to load module asset for $key: $e');
    }
    return null;
  }
}
      final normalizedMap = <String, String>{};
