import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_configuration_screen.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/schema_provider.dart';
import 'package:drivererpapp/providers/theme_provider.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/services/auth_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'dart:convert';
import 'package:flutter/services.dart';

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.contains('inventory.json')) {
      return jsonEncode({
        "settings": {
           "mode": {"type": "text", "label": "Mode", "value": "Standard"}
        }
      });
    }
    return "";
  }
  
  @override
  Future<ByteData> load(String key) async {
    if (key.contains('inventory.json')) {
       return ByteData.view(Uint8List.fromList(utf8.encode(await loadString(key))).buffer);
    }
    throw FlutterError('Asset not found');
  }
}

class MockDriveProvider extends Mock implements DriveProvider {}
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockAuthService extends Mock implements AuthService {}
class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockDriveProvider mockDriveProvider;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveService mockDriveService;
  late MockAuthService mockAuthService;
  late MockSchemaProvider mockSchemaProvider;
  late MockThemeProvider mockThemeProvider;

  setUp(() {
    mockDriveProvider = MockDriveProvider();
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveService = MockDriveService();
    mockAuthService = MockAuthService();
    mockSchemaProvider = MockSchemaProvider();
    mockThemeProvider = MockThemeProvider();

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    
    final workspace = drive.File()..id = 'ws_id'..name = 'Test Workspace';
    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(workspace);
    
    // Default success mock for creation
    when(() => mockDriveService.createWorkspace(any(), any())).thenAnswer((_) async => drive.File()..id = 'new_module_id');
    // Dashboard might request listModules
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => []);
  });

  Widget createScreen() {
    return DefaultAssetBundle(
      bundle: TestAssetBundle(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
          ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ],
        child: MaterialApp(
          home: ModuleConfigurationScreen(
            moduleInfo: const {'name': 'Inventory', 'color': '#FF0000'},
          ),
        ),
      ),
    );
  }

  testWidgets('ModuleConfigurationScreen renders', (WidgetTester tester) async {
    await tester.pumpWidget(createScreen());
    await tester.pump(); // allow Future in initState to complete

    expect(find.text('CONFIGURE INVENTORY'), findsOneWidget);
    expect(find.text('Customize your module'), findsOneWidget);
  });

  testWidgets('ModuleConfigurationScreen activates module', (WidgetTester tester) async {
    await tester.pumpWidget(createScreen());
    await tester.pump(); 
    
    // Check if still loading
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      // Pump to finish future
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }

    // Find "COMPLETE SETUP" button.
    final button = find.text('COMPLETE SETUP');
    
    // Debug output if not found
    if (button.evaluate().isEmpty) {
      debugPrint('Button not found. Trying to find any text...');
      debugPrint(find.byType(Text).evaluate().map((e) => (e.widget as Text).data).join(', '));
    }
    
    // Ensure button is present
    expect(button, findsOneWidget);
    
    await tester.tap(button);
    await tester.pump(); // Start activation
    await tester.pump(const Duration(milliseconds: 100)); 

    // Verify createWorkspace called with (workspaceId, moduleName)
    verify(() => mockDriveService.createWorkspace('ws_id', 'Inventory')).called(1);
    
    // Check for success snackbar
    expect(find.text('Inventory activated successfully!'), findsOneWidget);
  });
}
