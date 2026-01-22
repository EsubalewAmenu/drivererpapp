import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:drivererpapp/screens/module_configuration_screen.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/models/company_model.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockAuthService extends Mock implements AuthService {}

class _TestGoogleAccount extends Fake implements GoogleSignInAccount {
  final String _email;
  _TestGoogleAccount(this._email);
  @override
  String get email => _email;
}

class TestAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;
  TestAssetBundle({required this.assets});

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    // Provide a dynamic `module_asset_map.json` based on the provided
    // assets so tests can exercise the authoritative map lookup.
    if (key == 'assets/erp_modules/module_asset_map.json') {
      final map = <String, String>{};
      for (final entry in assets.entries) {
        final path = entry.key;
        if (path.startsWith('assets/erp_modules/') && path.endsWith('.json')) {
          final filename = path.split('/').last;
          final name = filename.replaceAll('.json', '').toLowerCase();
          map[name] = filename;
        }
      }
      return jsonEncode(map);
    }

    if (assets.containsKey(key)) {
      return assets[key]!;
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async => ByteData(0);
}

void main() {
  // Disable Provider runtime-type check for tests that inject mock instances
  Provider.debugCheckInvalidValueType = null;
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockAuthService = MockAuthService();

    when(() => mockWorkspaceProvider.currentWorkspace).thenReturn(
      drive.File(id: 'w1', name: 'Test Company'),
    );
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockAuthService.currentUser).thenReturn(_TestGoogleAccount('user@example.com'));
    when(() => mockDriveService.createWorkspace(any(), any())).thenAnswer((_) async => drive.File(id: 'new_folder_id', name: 'New Folder'));
    when(() => mockDriveService.listModules(any())).thenAnswer((_) async => <drive.File>[]);
  });

  Widget createScreen(Map<String, String> moduleInfo, AssetBundle bundle) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
        Provider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: ModuleConfigurationScreen(moduleInfo: moduleInfo),
        ),
      ),
    );
  }

  group('ModuleConfigurationScreen Tests', () {
    testWidgets('loads fallback when asset not found', (WidgetTester tester) async {
      final moduleInfo = {'name': 'Inventory', 'color': '#F59E0B'};
      final bundle = TestAssetBundle(assets: {});

      await tester.pumpWidget(createScreen(moduleInfo, bundle));
      await tester.pumpAndSettle();

      expect(find.text('CONFIGURE INVENTORY'), findsOneWidget);
      expect(find.text('MODULE NAME'), findsOneWidget);
      expect(find.text('COMPLETE SETUP'), findsOneWidget);
    });

    testWidgets('loads specific module config from JSON', (WidgetTester tester) async {
      final moduleInfo = {'name': 'CRM', 'color': '#10B981'};
      final crmJson = jsonEncode({
        'settings': {
          'business_type': {
            'label': 'Business Type',
            'type': 'select',
            'options': ['Retail', 'Service'],
            'value': 'Retail'
          },
          'enable_leads': {
            'label': 'Enable Leads',
            'type': 'boolean',
            'value': true
          },
          'warehouses': {
            'label': 'Warehouses',
            'type': 'list',
            'value': ['Main']
          }
        }
      });
      
      final bundle = TestAssetBundle(assets: {
        'assets/erp_modules/crm.json': crmJson,
      });

      await tester.pumpWidget(createScreen(moduleInfo, bundle));
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('CONFIGURE CRM'), findsOneWidget);
      expect(find.text('BUSINESS TYPE'), findsOneWidget);
      expect(find.text('ENABLE LEADS'), findsOneWidget);
      expect(find.text('WAREHOUSES'), findsOneWidget);
      expect(find.text('Main'), findsOneWidget);
    });

    testWidgets('activates module successfully', (WidgetTester tester) async {
      final moduleInfo = {'name': 'Inventory', 'color': '#F59E0B'};
      final bundle = TestAssetBundle(assets: {});

      await tester.pumpWidget(createScreen(moduleInfo, bundle));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'My Inventory');
      await tester.tap(find.text('COMPLETE SETUP'));
      
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      verify(() => mockDriveService.createWorkspace('w1', 'My Inventory')).called(1);
      // SnackBar might be gone if we navigated, but we check navigation worked
      expect(find.text('My Inventory activated successfully!'), findsWidgets);
    });

    testWidgets('handles activation error', (WidgetTester tester) async {
      final moduleInfo = {'name': 'Inventory', 'color': '#F59E0B'};
      final bundle = TestAssetBundle(assets: {});

      when(() => mockDriveService.createWorkspace(any(), any())).thenThrow(Exception('Drive Error'));

      await tester.pumpWidget(createScreen(moduleInfo, bundle));
      await tester.pumpAndSettle();

      await tester.tap(find.text('COMPLETE SETUP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error activating module: Exception: Drive Error'), findsOneWidget);
    });

    testWidgets('adds and removes items in list field', (WidgetTester tester) async {
      final moduleInfo = {'name': 'Inventory', 'color': '#F59E0B'};
      final json = jsonEncode({
        'settings': {
          'locs': {
            'label': 'Locations',
            'type': 'list',
            'value': ['Loc 1']
          }
        }
      });
      final bundle = TestAssetBundle(assets: {'assets/erp_modules/inventory.json': json});

      await tester.pumpWidget(createScreen(moduleInfo, bundle));
      await tester.pumpAndSettle();

      // Add item
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('New Warehouse'), findsOneWidget);

      // Remove item
      await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Loc 1'), findsNothing);
    });

    testWidgets('updates UI based on boolean dependencies', (WidgetTester tester) async {
       final moduleInfo = {'name': 'Inventory', 'color': '#F59E0B'};
      final json = jsonEncode({
        'settings': {
          'show_advanced': {
            'label': 'Advanced',
            'type': 'boolean',
            'value': false
          },
          'extra_field': {
            'label': 'Extra Field',
            'type': 'text',
            'dependsOn': 'show_advanced'
          }
        }
      });
      final bundle = TestAssetBundle(assets: {'assets/erp_modules/inventory.json': json});

      await tester.pumpWidget(createScreen(moduleInfo, bundle));
      await tester.pumpAndSettle();

      expect(find.text('EXTRA FIELD'), findsNothing);

      // Toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('EXTRA FIELD'), findsOneWidget);
    });
    
    testWidgets('updates dropdown value', (WidgetTester tester) async {
       final moduleInfo = {'name': 'Inventory', 'color': '#F59E0B'};
      final json = jsonEncode({
        'settings': {
          'type': {
            'label': 'Type',
            'type': 'select',
            'options': ['A', 'B'],
            'value': 'A'
          }
        }
      });
      final bundle = TestAssetBundle(assets: {'assets/erp_modules/inventory.json': json});

      await tester.pumpWidget(createScreen(moduleInfo, bundle));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();

      expect(find.text('B'), findsWidgets);
    });
  });
}
