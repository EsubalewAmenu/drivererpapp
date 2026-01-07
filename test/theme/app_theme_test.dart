import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    AppTheme.useGoogleFonts = false;
  });

  test('AppTheme returns light theme', () {
    final theme = AppTheme.lightTheme;
    expect(theme.brightness, Brightness.light);
    expect(theme.primaryColor, AppTheme.primaryColor);
    expect(theme.scaffoldBackgroundColor, AppTheme.lightBackgroundColor);
    expect(theme.cardTheme.color, AppTheme.lightSurfaceColor);
    expect(theme.textTheme.bodyLarge?.color, AppTheme.lightTextColor);
  });

  test('AppTheme returns dark theme', () {
    final theme = AppTheme.darkTheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.primaryColor, AppTheme.primaryColor);
    expect(theme.scaffoldBackgroundColor, AppTheme.backgroundColor);
    expect(theme.cardTheme.color, AppTheme.surfaceColor);
    expect(theme.textTheme.bodyLarge?.color, AppTheme.textColor);
  });

  test('AppTheme helpers return styles', () {
    final style = AppTheme.inter(fontSize: 20, color: Colors.red);
    expect(style.fontSize, 20);
    expect(style.color, Colors.red);

    final mono = AppTheme.sourceCodePro(fontSize: 14);
    expect(mono.fontSize, 14);
    expect(mono.fontFamily, 'Monospace');
  });
}
