import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/drive_provider.dart';
import 'workspace_selector_screen.dart';

class SystemScanningScreen extends StatefulWidget {
  const SystemScanningScreen({super.key});

  @override
  State<SystemScanningScreen> createState() => _SystemScanningScreenState();
}

class _SystemScanningScreenState extends State<SystemScanningScreen> {
  String _statusMessage = "Initializing system...";
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // Start scanning after the first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanningSequence();
    });
  }

  Future<void> _startScanningSequence() async {
    try {
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);
      
      // Wait for drive service if not ready
      if (driveProvider.driveService == null) {
        setState(() => _statusMessage = "Waiting for authentication...");
        // In a real app, you might want to retry or redirect to login
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        if (driveProvider.driveService == null) {
           // Fallback or error
           setState(() => _statusMessage = "Authentication failed.");
           return;
        }
      }

      final driveService = driveProvider.driveService!;

      // Step 1: Check Root Folder
      setState(() {
        _statusMessage = "Scanning Drive for DriveERP_Data...";
        _progress = 0.2;
      });
      
      String? rootFolderId = await driveService.checkRootFolder();

      // Step 2: Create Root Folder if missing
      if (rootFolderId == null) {
        setState(() {
          _statusMessage = "Initializing DriveERP_Data environment...";
          _progress = 0.4;
        });
        rootFolderId = await driveService.createRootFolder();
      } else {
        setState(() {
          _statusMessage = "DriveERP_Data found. Verifying integrity...";
          _progress = 0.5;
        });
        await Future.delayed(const Duration(milliseconds: 500)); // UX delay
      }

      // Step 3: List Workspaces
      setState(() {
        _statusMessage = "Syncing workspace configuration...";
        _progress = 0.7;
      });

      final workspaces = await driveService.listWorkspaces(rootFolderId);

      // Step 4: Ready
      setState(() {
        _statusMessage = "System ready.";
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WorkspaceSelectorScreen(
              workspaces: workspaces,
              rootFolderId: rootFolderId!,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        String errorMessage = "System Error: $e";
        if (e.toString().contains("disabled") || e.toString().contains("has not been used")) {
           errorMessage = "API Error: Google Drive API is not enabled.\nPlease enable it in Google Cloud Console.";
        }
        
        setState(() {
          _statusMessage = errorMessage;
          _progress = 0.0;
        });
        debugPrint("Scanning Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              
              // Scanning Icon / Animation
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 48),

              // Terminal-style output
              Text(
                'SYSTEM INITIALIZATION',
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 12,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Status Message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusMessage,
                  key: ValueKey<String>(_statusMessage),
                  style: GoogleFonts.sourceCodePro( // Monospace for technical feel
                    color: AppTheme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.surfaceColor,
                  color: AppTheme.primaryColor,
                  minHeight: 4,
                ),
              ),

              const Spacer(),
              
              // Footer
              Center(
                child: Text(
                  'ID: 84-F9-22-01', // Mock Session ID
                  style: GoogleFonts.inter(
                    color: AppTheme.surfaceColor,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
