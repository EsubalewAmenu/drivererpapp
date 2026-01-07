import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/screens/common/history_dialog.dart';
import 'package:drivererpapp/services/drive_service.dart';

class MockDriveService extends Mock implements DriveService {}

void main() {
  late MockDriveService mockDriveService;

  setUp(() {
    mockDriveService = MockDriveService();
  });

  testWidgets('HistoryDialog displays loading and then revisions', (WidgetTester tester) async {
    final now = DateTime.now();
    final revision = drive.Revision()
      ..id = 'rev1'
      ..modifiedTime = now
      ..lastModifyingUser = (drive.User()..displayName = 'Test User');

    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'file123');
    when(() => mockDriveService.getFileRevisions('file123')).thenAnswer((_) async => [revision]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryDialog(
            moduleId: 'mod1',
            moduleName: 'Inventory',
            driveService: mockDriveService,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.textContaining('Modified by Test User'), findsOneWidget);
    expect(find.text('V1'), findsOneWidget);
  });

  testWidgets('HistoryDialog shows error when file not found', (WidgetTester tester) async {
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryDialog(
            moduleId: 'mod1',
            moduleName: 'Inventory',
            driveService: mockDriveService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('File "Inventory" not found'), findsOneWidget);
  });
}
