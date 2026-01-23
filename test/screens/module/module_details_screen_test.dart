import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:drivererpapp/screens/module_details_screen.dart';

class TestAssetBundle extends AssetBundle {
  final Map<String, String> files;
  final bool failMap;
  TestAssetBundle({required this.files, this.failMap = false});

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('module_asset_map.json')) {
      if (failMap) throw Exception('map missing');
      // module_asset_map expects mapping of shortKey -> fileName
      final map = <String, String>{};
      files.forEach((k, v) {
        if (k.endsWith('.json')) {
          // file entries; skip
        } else {
          map[k] = v;
        }
      });
      return jsonEncode(map);
    }
    final name = key.split('/').last;
    if (files.containsKey(name)) return files[name]!;
    throw Exception('asset not found: $key');
  }
}

void main() {
  testWidgets('ModuleDetailsScreen shows name, desc and activate button', (tester) async {
    final moduleInfo = {
      'id': 'inventory',
      'name': 'Inventory',
      'desc': 'Manage stock and variants',
      'icon': 'inventory',
      'color': '#FF0000',
    };

    final bundle = TestAssetBundle(files: {
      'inventory': 'inventory.json',
      'inventory.json': jsonEncode({
        'tabs': [],
        'settings': {'name': {'label': 'Name', 'type': 'text', 'value': 'Inventory'}}
      }),
    });

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(home: ModuleDetailsScreen(moduleInfo: moduleInfo)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('INVENTORY'), findsOneWidget);
    expect(find.textContaining('Manage stock'), findsOneWidget);
    expect(find.text('ACTIVATE'), findsOneWidget);
  });

  testWidgets('ModuleDetailsScreen shows error and retry for HR when asset load fails', (tester) async {
    final moduleInfo = {
      'id': 'hr',
      'name': 'HR',
      'desc': 'Human Resources',
      'icon': 'people',
      'color': '#00FF00',
    };

    final bundle = TestAssetBundle(files: {}, failMap: true);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(home: ModuleDetailsScreen(moduleInfo: moduleInfo)),
      ),
    );

    // Allow didChangeDependencies -> _loadModuleConfig to run
    await tester.pumpAndSettle();

    expect(find.text('Error Loading Module'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
  });
}
