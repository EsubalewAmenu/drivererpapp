import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:drivererpapp/screens/common/history_dialog.dart';
import 'package:drivererpapp/services/drive_service.dart';
import 'package:intl/intl.dart';

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

  testWidgets('HistoryDialog displays Yesterday and specific dates', (WidgetTester tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final lastWeek = now.subtract(const Duration(days: 7));

    final rev1 = drive.Revision()
      ..id = '1'
      ..modifiedTime = now
      ..lastModifyingUser = (drive.User()..displayName = 'User 1');
    final rev2 = drive.Revision()
      ..id = '2'
      ..modifiedTime = yesterday
      ..lastModifyingUser = (drive.User()..displayName = 'User 2');
    final rev3 = drive.Revision()
      ..id = '3'
      ..modifiedTime = lastWeek
      ..lastModifyingUser = (drive.User()..displayName = 'User 3');

    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'f1');
    when(() => mockDriveService.getFileRevisions('f1')).thenAnswer((_) async => [rev3, rev2, rev1]);

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

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text(DateFormat.yMMMd().format(lastWeek).toUpperCase()), findsOneWidget);
    
    // Check versions: rev1 is newest (V3), rev2 is middle (V2), rev3 is oldest (V1)
    expect(find.text('V3'), findsOneWidget);
    expect(find.text('V2'), findsOneWidget);
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

  testWidgets('HistoryDialog shows "No revision history available" when list is empty', (WidgetTester tester) async {
    when(() => mockDriveService.getFileId(any(), any())).thenAnswer((_) async => 'f1');
    when(() => mockDriveService.getFileRevisions('f1')).thenAnswer((_) async => []);

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

    expect(find.text('No revision history available.'), findsOneWidget);
  });
}
