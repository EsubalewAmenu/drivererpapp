import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:drivererpapp/providers/workspace_provider.dart';
import 'package:drivererpapp/screens/dynamic_form/fields/media_field.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:drivererpapp/models/schema_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

// Mocks
class MockWorkspaceProvider extends Mock implements WorkspaceProvider {}
class MockDriveProvider extends Mock implements DriveProvider {}
class MockDriveService extends Mock implements DriveService {}
class MockDriveApi extends Mock implements drive.DriveApi {}
class MockPermissionsResource extends Mock implements drive.PermissionsResource {}

void main() {
  late MockWorkspaceProvider mockWorkspaceProvider;
  late MockDriveProvider mockDriveProvider;
  late MockDriveService mockDriveService;
  late MockDriveApi mockDriveApi;
  late MockPermissionsResource mockPermissionsResource;

  setUp(() {
    mockWorkspaceProvider = MockWorkspaceProvider();
    mockDriveProvider = MockDriveProvider();
    mockDriveService = MockDriveService();
    mockDriveApi = MockDriveApi();
    mockPermissionsResource = MockPermissionsResource();

    // Setup nested mocks
    when(() => mockDriveProvider.driveService).thenReturn(mockDriveService);
    when(() => mockDriveService.driveApi).thenReturn(mockDriveApi);
    when(() => mockDriveApi.permissions).thenReturn(mockPermissionsResource);
  });

  Widget createSubject({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkspaceProvider>.value(value: mockWorkspaceProvider),
        ChangeNotifierProvider<DriveProvider>.value(value: mockDriveProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('DynamicMediaField displays placeholder when value is empty', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'photo', label: 'Photo', type: 'image');

    await tester.pumpWidget(createSubject(
      child: DynamicMediaField(
        column: column,
        value: null,
        primaryColor: Colors.blue,
        onChanged: (_) {},
        type: 'image',
      ),
    ));

    expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
    expect(find.text('Tap to pick or capture image'), findsOneWidget);
  });

  testWidgets('DynamicMediaField displays image when value matches URL pattern', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'photo', label: 'Photo', type: 'image');
    const imageUrl = 'https://example.com/image.jpg';

    await tester.pumpWidget(createSubject(
      child: DynamicMediaField(
        column: column,
        value: imageUrl,
        primaryColor: Colors.blue,
        onChanged: (_) {},
        type: 'image',
      ),
    ));

    expect(find.byType(Image), findsOneWidget);
    // Should show edit and delete buttons
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('DynamicMediaField displays image when value is an ID', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'photo', label: 'Photo', type: 'image');
    const imageId = '12345';

    await tester.pumpWidget(createSubject(
      child: DynamicMediaField(
        column: column,
        value: imageId,
        primaryColor: Colors.blue,
        onChanged: (_) {},
        type: 'image',
      ),
    ));

    expect(find.byType(Image), findsOneWidget);
  });
  
  testWidgets('DynamicMediaField delete button triggers input clearing', (WidgetTester tester) async {
    final column = ColumnConfig(key: 'photo', label: 'Photo', type: 'image');
    String? capturedValue;

    await tester.pumpWidget(createSubject(
      child: DynamicMediaField(
        column: column,
        value: '12345',
        primaryColor: Colors.blue,
        onChanged: (val) => capturedValue = val,
        type: 'image',
      ),
    ));

    // Tap delete
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    expect(capturedValue, isEmpty);
  });
}
