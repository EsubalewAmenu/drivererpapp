import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/schema_models.dart';

class SchemaService {
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
        print('Error loading module $file: $e');
      }
    }

    return modules;
  }
}
