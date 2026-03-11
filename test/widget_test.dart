import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivererpapp/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MainApp renders landing content', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pump();

    expect(find.text('DRIVE ERP'), findsOneWidget);
  });
}
