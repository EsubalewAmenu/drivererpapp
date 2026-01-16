import 'package:flutter/foundation.dart';
import '../services/drive_service.dart';
import '../services/schema_service.dart';
import '../models/schema_models.dart';

class SchemaProvider extends ChangeNotifier {
  final SchemaService _schemaService;
  final Map<String, ModuleSchema> _memoryCache = {};

  SchemaProvider({DriveService? driveService, String? userEmail}) 
      : _schemaService = SchemaService(driveService: driveService, userEmail: userEmail);

  SchemaService get service => _schemaService;

  /// Returns a cached schema from memory if available.
  ModuleSchema? getFromMemory(String moduleId) => _memoryCache[moduleId];

  /// Attempts to find a cached module by id or by name (case-insensitive).
  ModuleSchema? findModuleByIdOrName(String idOrName) {
    final byId = getFromMemory(idOrName);
    if (byId != null) return byId;
    try {
      return _memoryCache.values.firstWhere((m) => m.name.toLowerCase() == idOrName.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Attempts to find a cached module that contains a tab with the given tab id.
  ModuleSchema? findModuleByTabId(String tabId) {
    try {
      return _memoryCache.values.firstWhere((m) => m.tabs.any((t) => t.id == tabId));
    } catch (e) {
      return null;
    }
  }

  /// Updates the memory cache.
  void updateMemoryCache(String moduleId, ModuleSchema? schema) {
    if (schema == null) {
      _memoryCache.remove(moduleId);
    } else {
      _memoryCache[moduleId] = schema;
    }
    notifyListeners();
  }

  /// Saves the schema and updates memory.
  Future<bool> saveConfig(ModuleSchema config) async {
    try {
      await _schemaService.saveModuleConfig(config.id, config);
      updateMemoryCache(config.id, config);
      return true;
    } catch (e) {
      debugPrint('Error saving config: $e');
      return false;
    }
  }

  /// No-op for now, but could be used to notify all screens of schema updates.
  void notifyUpdate() {
    notifyListeners();
  }
}
