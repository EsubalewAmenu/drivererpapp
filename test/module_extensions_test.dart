import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:drivererpapp/providers/erp_controller.dart';
import 'package:drivererpapp/screens/erp_app.dart';
import 'package:drivererpapp/services/erp_api.dart';

ModuleSchema fixture(String key, {String? parent}) => ModuleSchema(
  id: key,
  name: key == 'crm' ? 'CRM' : 'Deals',
  icon: 'people',
  primaryColor: '#10B981',
  version: 1,
  templateKey: key,
  extensionKeys: key == 'crm' ? ['deals', 'support'] : [],
  parentKey: parent == null ? null : 'crm',
  parentModuleId: parent,
  settings: {},
  dashboard: DashboardConfig(cards: []),
  collections: [
    CollectionSchema(
      id: key == 'crm' ? 'contacts' : 'deals',
      label: key == 'crm' ? 'Directory' : 'Pipeline',
      fields: [FieldDefinition(key: 'name', label: 'Name', type: 'text')],
    ),
  ],
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'extensions are excluded from landing modules and grouped by parent',
    () {
      final erp = ErpController();
      final crm = fixture('crm');
      final deals = fixture('deals', parent: crm.id);
      erp.modules = [crm, deals];
      expect(erp.rootModules.map((m) => m.id), ['crm']);
      expect(erp.extensionsFor(crm).single.id, 'deals');
      expect(ModuleSchema.fromJson(deals.toJson()).parentModuleId, 'crm');
      expect(deals.copyWith(name: 'Renamed').isExtension, isTrue);
    },
  );
  test('every extension template declares a valid root parent', () {
    final modules = Directory('assets/erp_modules')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => ModuleSchema.fromJson(jsonDecode(f.readAsStringSync())))
        .toList();
    for (final child in modules.where((m) => m.isExtension)) {
      final parent = modules.singleWhere((m) => m.id == child.parentKey);
      expect(parent.isExtension, isFalse);
    }
    expect(modules.singleWhere((m) => m.id == 'deals').parentKey, 'crm');
  });
  testWidgets(
    'parent workspace includes active extension collections and extension management',
    (tester) async {
      final api = ErpApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/dashboard')) {
            return http.Response('{"cards":[]}', 200);
          }
          return http.Response(
            '{"records":[],"total":0,"has_more":false}',
            200,
          );
        }),
      );
      final erp = ErpController(api: api)
        ..modules = [fixture('crm'), fixture('deals', parent: 'crm')];
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: erp,
          child: const MaterialApp(home: NativeModuleScreen(moduleId: 'crm')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Directory'), findsOneWidget);
      expect(find.text('Deals · Pipeline'), findsOneWidget);
      expect(find.byTooltip('Extensions'), findsOneWidget);
      await tester.tap(find.text('Deals · Pipeline'));
      await tester.pumpAndSettle();
      erp.modules = [fixture('crm')];
      erp.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Deals · Pipeline'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('main catalog lists roots and keeps Deals inside CRM', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ErpController(),
        child: const MaterialApp(home: ModuleCatalogScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Deals'), findsNothing);
    expect(find.text('Support Tickets'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
