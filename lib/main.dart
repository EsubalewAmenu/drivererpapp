import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'providers/workspace_provider.dart';
import 'providers/drive_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Added ThemeProvider
        ChangeNotifierProxyProvider<AuthService, DriveProvider>(
          create: (_) => DriveProvider(),
          update: (_, auth, drive) {
            final d = drive ?? DriveProvider();
            d.updateClient(auth.authClient);
            return d;
          },
        ),
        ChangeNotifierProxyProvider<DriveProvider, SyncProvider>(
          create: (_) => SyncProvider(),
          update: (_, drive, sync) {
            final s = sync ?? SyncProvider();
            s.updateDriveProvider(drive);
            return s;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DriveERP',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const LandingScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
