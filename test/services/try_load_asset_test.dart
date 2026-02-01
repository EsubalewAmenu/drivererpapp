import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/services/schema_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tryLoadModuleAsset uses module_asset_map.json to resolve CRM', () async {
    // Load the actual asset files from disk to use in the mock handler
    final projectRoot = Directory.current.path;
    final mapPath = '$projectRoot/assets/erp_modules/module_asset_map.json';
    final crmPath = '$projectRoot/assets/erp_modules/crm.json';

    final mapStr = await File(mapPath).readAsString();
    final crmStr = await File(crmPath).readAsString();

    // Mock the asset channel to return appropriate content based on requested key
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        if (message == null) return null;
        final key = utf8.decoder.convert(message.buffer.asUint8List());
        if (key.endsWith('module_asset_map.json')) {
          final bytes = utf8.encoder.convert(mapStr);
          return ByteData.view(Uint8List.fromList(bytes).buffer);
        }
        if (key.endsWith('crm.json')) {
          final bytes = utf8.encoder.convert(crmStr);
          return ByteData.view(Uint8List.fromList(bytes).buffer);
        }
        return null;
      },
    );

    final res = await SchemaService.tryLoadModuleAsset('crm');
    expect(res, isNotNull);
    expect(res, contains('CRM'));
  });
}
