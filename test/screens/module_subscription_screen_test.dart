import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/screens/module_subscription_screen.dart';
import '../helpers/fake_billing_http_overrides.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late WorkspaceProvider workspaceProvider;
  late MockAuthService mockAuthService;

  setUp(() {
    workspaceProvider = WorkspaceProvider(driveService: null);
    mockAuthService = MockAuthService();
  });

  Widget _buildScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaceProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
      ],
      child: const MaterialApp(
        home: ModuleSubscriptionScreen(
          email: 'user@example.com',
          spreadsheetId: 'sheet123',
          moduleId: 'support_tickets',
          moduleName: 'Support',
        ),
      ),
    );
  }

  Future<void> pumpWithFakeHttp(WidgetTester tester) async {
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(_buildScreen());
      },
      createHttpClient: (context) => FakeBillingHttpOverrides().createHttpClient(context),
    );
  }

  testWidgets('renders subscription app bar title', (tester) async {
    await pumpWithFakeHttp(tester);

    expect(find.text('SUPPORT SUBSCRIPTION'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('renders subscription tab shell', (tester) async {
    await pumpWithFakeHttp(tester);

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.textContaining('SUPPORT'), findsWidgets);
  });
}
