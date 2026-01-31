import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/module_details_screen.dart';

class _FakeBundle extends AssetBundle {
  final Map<String, String> assets;
  _FakeBundle(this.assets);
  @override
  Future<ByteData> load(String key) async => throw Exception('not used');
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (assets.containsKey(key)) return assets[key]!;
    throw Exception('not found');
  }
}

void main() {
  testWidgets('ModuleDetailsScreen shows features for Inventory and handles missing HR asset', (tester) async {
    final infoInv = {'id': 'inv', 'name': 'Inventory', 'color': '#2196F3', 'desc': 'Desc', 'icon': 'help'};

    // HR with missing asset should show error message
    final infoHr = {'id': 'hr', 'name': 'HR', 'color': '#2196F3', 'desc': 'Desc', 'icon': 'help'};
    await tester.pumpWidget(MaterialApp(home: DefaultAssetBundle(bundle: _FakeBundle({}), child: ModuleDetailsScreen(moduleInfo: infoHr))));
    await tester.pumpAndSettle();

    expect(find.text('Error Loading Module'), findsOneWidget);
  });
}
