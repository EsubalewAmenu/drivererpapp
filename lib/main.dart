import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'providers/workspace_provider.dart';
import 'providers/drive_provider.dart';
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
        ChangeNotifierProxyProvider<AuthService, DriveProvider>(
          create: (_) => DriveProvider(),
          update: (_, auth, drive) {
            final d = drive ?? DriveProvider();
            d.updateClient(auth.authClient);
            return d;
          },
        ),
      ],
      child: MaterialApp(
        title: 'DriveERP',
        theme: AppTheme.darkTheme,
        home: const LandingScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
