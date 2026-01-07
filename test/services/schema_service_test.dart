import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/services/schema_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SchemaService loads modules from assets', () async {
    final schemaService = SchemaService();
    
    // Mock rootBundle
    final testSchema = {
      'id': 'inventory',
      'name': 'Inventory',
      'icon': 'inventory',
      'primaryColor': '#F59E0B',
      'version': '1.0.0',
      'settings': {},
      'tabs': [],
      'dashboard': {'kpiCards': []}
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final Uint8List encoded = utf8.encoder.convert(jsonEncode(testSchema));
        return encoded.buffer.asByteData();
      },
    );

    final modules = await schemaService.loadModules();
    expect(modules.length, 1);
    expect(modules[0].id, 'inventory');
  });
}
