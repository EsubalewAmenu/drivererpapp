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

  /// Updates the memory cache.
  void updateMemoryCache(String moduleId, ModuleSchema? schema) {
    if (schema == null) {
      _memoryCache.remove(moduleId);
    } else {
      _memoryCache[moduleId] = schema;
    }
    notifyListeners();
  }

  /// No-op for now, but could be used to notify all screens of schema updates.
  void notifyUpdate() {
    notifyListeners();
  }
}
