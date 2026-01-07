import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/widgets/app_drawer.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockAuthService extends Mock implements AuthService {}
class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockAuthService mockAuthService;
  late MockThemeProvider mockThemeProvider;

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockAuthService = MockAuthService();
    mockThemeProvider = MockThemeProvider();

    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(drive.File()..name = 'Test Workspace');
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
  });

  Widget createDrawer() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          drawer: AppDrawer(),
        ),
      ),
    );
  }

  testWidgets('AppDrawer renders workspace name and nav links', (WidgetTester tester) async {
    await tester.pumpWidget(createDrawer());
    
    // Open drawer
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('DRIVE ERP'), findsOneWidget);
    expect(find.text('Test Workspace'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
