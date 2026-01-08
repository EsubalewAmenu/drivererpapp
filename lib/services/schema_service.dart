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
  final String? userEmail;

  SchemaService({this.driveService, this.userEmail});

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
      String? configFileId;
      
      // New logic: Look in config folder first if user email is present
      if (userEmail != null) {
        try {
          final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
          final fileName = '${userEmail}_config';
          configFileId = await driveService!.getFileId(configFolderId, fileName);
        } catch (e) {
          debugPrint('Error looking up user config: $e');
        }
      }

      // Fallback: Look for legacy config file in module root
      if (configFileId == null) {
         configFileId = await driveService!.getFileId(moduleId, 'config');
      }

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
      String? fileId;
      
      if (userEmail != null) {
        // 1. Prepare target location: config/email_config
        final configFolderId = await driveService!.getOrCreateSubFolder(moduleId, 'config');
        final fileName = '${userEmail}_config';
        
        fileId = await driveService!.getFileId(configFolderId, fileName);
        
        // 2. Prepare config map
        final configMap = config.toJson();

        if (fileId != null) {
           // Update existing user config
           await driveService!.updateModuleConfig(fileId, configMap);
        } else {
           // Create new user config
           fileId = await driveService!.createModuleConfig(configFolderId, fileName, configMap);
        }
      } else {
        // Legacy/Fallback behavior: config in root
        fileId = await driveService!.getFileId(moduleId, 'config');
        if (fileId == null) throw Exception('Config file not found and no user email to create new one');
         
        await driveService!.updateModuleConfig(fileId, config.toJson());
      }

      // 4. Update Cache
      // Fetch updated metadata so we are in sync
      final modifiedTime = await driveService!.getFileModifiedTime(fileId!);
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
