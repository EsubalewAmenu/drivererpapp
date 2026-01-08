import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivererpapp/providers/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider', () {
    test('Initial theme should be system', () async {
      final provider = ThemeProvider();
      // Need to wait for _loadTheme to complete since it's called in constructor
      // but it's not awaited there. In real app it just loads eventually.
      // For testing we might need a small delay or check behavior after it loads.
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.system);
    });

    test('toggleTheme should switch between light and dark', () async {
      final provider = ThemeProvider();
      await Future.delayed(Duration.zero);
      
      // Default system usually depends on platform, but we can force it to light/dark
      // and then toggle.
      // Initially system. If we toggle, it should go to dark (if it was lightish) or light.
      // Let's check toggle logic in provider.
      
      // If we call toggleTheme() multiple times
      provider.toggleTheme();
      expect(provider.themeMode, anyOf(ThemeMode.light, ThemeMode.dark));
      
      final firstMode = provider.themeMode;
      provider.toggleTheme();
      expect(provider.themeMode, isNot(firstMode));
    });

    test('isDarkMode should return correct value based on themeMode', () async {
      final provider = ThemeProvider();
      await Future.delayed(Duration.zero);

      // Force to dark
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.isDarkMode, isTrue);

      // Toggle to light
      provider.toggleTheme();
      expect(provider.isDarkMode, isFalse);
    });

    test('setThemeMode should persist value', () async {
      final provider = ThemeProvider();
      await provider.setThemeMode(ThemeMode.dark);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('loadTheme should reading from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      
      final provider = ThemeProvider();
      await Future.delayed(Duration.zero);
      
      expect(provider.themeMode, ThemeMode.light);
    });
  });
}
