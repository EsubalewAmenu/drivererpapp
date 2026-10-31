import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/providers/erp_controller.dart';
import 'package:drivererpapp/services/erp_api.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/erp_app.dart';

void main() {
  testWidgets('create company closes input safely and opens native dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = ErpApi(
      client: MockClient((r) async {
        final path = r.url.path;
        if (path.endsWith('/companies') && r.method == 'GET') {
          return http.Response('{"companies":[]}', 200);
        }
        if (path.endsWith('/companies') && r.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'c1',
              'name': 'Native Test Company',
              'role': 'owner',
              'status': 'active',
            }),
            200,
          );
        }
        if (path.endsWith('/modules')) {
          return http.Response('{"modules":[]}', 200);
        }
        if (path.endsWith('/dashboard')) {
          return http.Response(
            '{"module_count":0,"record_count":0,"modules":[]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ErpController(api: api)),
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const MaterialApp(home: WorkspaceHome()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create company'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Native Test Company');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Native Test Company'), findsOneWidget);
    expect(find.text('Add module'), findsOneWidget);
  });
}
