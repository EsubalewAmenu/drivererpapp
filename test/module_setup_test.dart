import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/providers/erp_controller.dart';
import 'package:drivererpapp/screens/erp_app.dart';
import 'package:drivererpapp/services/erp_api.dart';
import 'module_extensions_test.dart' show fixture;

void main() {
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'sample records default on and installed core templates are hidden',
    (tester) async {
      final erp = ErpController()..modules = [fixture('crm')];
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: erp,
          child: const MaterialApp(home: ModuleCatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(find.text('CRM'), findsNothing);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.textContaining('collections'), findsNothing);
    },
  );
  test('extension request explicitly includes sample records', () async {
    final template = fixture('deals', parent: 'crm');
    final api = ErpApi(
      client: MockClient((r) async {
        expect(jsonDecode(r.body)['include_samples'], isTrue);
        return http.Response(jsonEncode(template.toJson()), 200);
      }),
    );
    await api.activateExtension('crm', template);
  });
  testWidgets('first-use extension hint opens controls and remains dismissed', (
    tester,
  ) async {
    final api = ErpApi(
      client: MockClient((r) async => http.Response('{"cards":[]}', 200)),
    );
    final erp = ErpController(api: api)..modules = [fixture('crm')];
    Widget app() => ChangeNotifierProvider.value(
      value: erp,
      child: const MaterialApp(home: NativeModuleScreen(moduleId: 'crm')),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap here for extensions'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Extensions'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('CRM extensions'), findsOneWidget);
    expect(find.text('Deals'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap here for extensions'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap here for extensions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
