import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schema_models.dart';
import 'drive_service.dart';

class SchemaService {
  static const String _cachePrefix = 'module_config_';
  static const String _metaPrefix = 'module_meta_';

  final DriveService? driveService;

  SchemaService({this.driveService});

  /// Loads the module configuration from local cache if available.
  Future<Map<String, dynamic>?> getCachedConfig(String moduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('$_cachePrefix$moduleId');
      if (cachedJson != null) {
        return jsonDecode(cachedJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading cached config: $e');
    }
    return null;
  }

  /// Saves the module configuration to local cache.
  Future<void> cacheConfig(String moduleId, Map<String, dynamic> config, {String? fileId, String? modifiedTime}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$moduleId', jsonEncode(config));
      
      if (fileId != null && modifiedTime != null) {
        final meta = {
          'fileId': fileId,
          'modifiedTime': modifiedTime,
        };
        await prefs.setString('$_metaPrefix$moduleId', jsonEncode(meta));
      }
    } catch (e) {
      debugPrint('Error caching config: $e');
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
  Future<Map<String, dynamic>?> syncConfig(String moduleId) async {
    if (driveService == null) return null;

    try {
      // 1. Get remote file info
      final configFileId = await driveService!.getFileId(moduleId, 'config');
      if (configFileId == null) return null;

      final remoteModifiedTime = await driveService!.getFileModifiedTime(configFileId);
      final remoteModifiedString = remoteModifiedTime?.toIso8601String();

      // 2. Check against local meta
      final localMeta = await getCachedMeta(moduleId);
      if (localMeta != null && 
          localMeta['fileId'] == configFileId && 
          localMeta['modifiedTime'] == remoteModifiedString) {
        debugPrint('Module $moduleId config is up to date.');
        return null; // Local is up-to-date, return null to indicate no change needed
      }

      // 3. Needs update
      debugPrint('Syncing module $moduleId config from Drive...');
      final newConfig = await driveService!.readModuleConfig(configFileId);
      
      // 4. Update cache
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
      // 1. Get file ID (try cache first, then lookup)
      String? fileId;
      final meta = await getCachedMeta(moduleId);
      fileId = meta?['fileId'];
      
      if (fileId == null) {
         fileId = await driveService!.getFileId(moduleId, 'config');
      }

      if (fileId == null) {
         throw Exception('Config file not found for module $moduleId');
      }

      // 2. Prepare config map for Spreadsheet Update
      final configMap = config.toJson();
      
      // 3. Update Drive via Sheets API
      // Instead of overwriting the file with raw JSON, we update the spreadsheet sheets
      await driveService!.updateModuleConfig(fileId, configMap);

      // 4. Update Cache
      // Fetch updated metadata so we are in sync
      final modifiedTime = await driveService!.getFileModifiedTime(fileId);
      if (modifiedTime != null) {
         await cacheConfig(moduleId, config.toJson(), fileId: fileId, modifiedTime: modifiedTime.toIso8601String());
      } else {
         // Fallback if we can't get time, at least update content
         await cacheConfig(moduleId, config.toJson());
      }
    } catch (e) {
      debugPrint('Error saving module config: $e');
      rethrow;
    }
  }

  Future<List<ModuleSchema>> loadModules() async {
    // In a real app, this might list files in the directory or read a manifest.
    // For now, we'll hardcode the list of known modules.
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
}
