import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'providers/workspace_provider.dart';
import 'providers/drive_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/schema_provider.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-initialize SharedPreferences for instant cache access
  await SharedPreferences.getInstance();
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
        ChangeNotifierProxyProvider2<AuthService, DriveProvider, SchemaProvider>(
          create: (_) => SchemaProvider(),
          update: (_, auth, drive, schema) {
            return SchemaProvider(
              driveService: drive.driveService, 
              userEmail: auth.currentUser?.email
            );
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
