import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../theme/app_theme.dart';
import '../providers/drive_provider.dart';
import '../providers/workspace_provider.dart';
import 'workspace_selector_screen.dart';
import 'dashboard_screen.dart';

class SystemScanningScreen extends StatefulWidget {
  const SystemScanningScreen({super.key});

  @override
  State<SystemScanningScreen> createState() => _SystemScanningScreenState();
}

class _SystemScanningScreenState extends State<SystemScanningScreen> {
  String _statusMessage = "Initializing system...";
  double _progress = 0.0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Start scanning after the first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanningSequence();
    });
  }

  Future<void> _startScanningSequence() async {
    // Reset state before starting
    if (_hasError) {
      setState(() {
        _hasError = false;
        _progress = 0.0;
        _statusMessage = "Retrying connection...";
      });
    }

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

      // Step 0: Check for saved workspace ID before scanning everything
      final lastWorkspaceId = await WorkspaceProvider.getLastWorkspaceId();
      if (lastWorkspaceId != null) {
        setState(() {
          _statusMessage = "Restoring previous workspace...";
        });
        try {
          final file = await driveService.driveApi.files.get(
            lastWorkspaceId,
            $fields: 'id, name, mimeType, parents, properties'
          ) as drive.File;

          if (mounted) {
            Provider.of<WorkspaceProvider>(context, listen: false).setWorkspace(file);
             
             setState(() {
              _statusMessage = "Welcome back, ${file.name}.";
              _progress = 1.0;
            });
            await Future.delayed(const Duration(milliseconds: 500)); 

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
              return;
            }
          }
        } catch (e) {
          debugPrint("Failed to restore workspace: $e. Proceeding with full scan.");
          // Fallback to normal flow
        }
      }

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
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains("disabled") || errorString.contains("has not been used")) {
           errorMessage = "API Error: Google Drive API is not enabled.\nPlease enable it in Google Cloud Console.";
        } else if (errorString.contains("socketexception") || 
                   errorString.contains("clientexception") ||
                   errorString.contains("failed host lookup") ||
                   errorString.contains("connection refused")) {
           errorMessage = "No Internet Connection.\nPlease check your network settings.";
        }
        
        setState(() {
          _statusMessage = errorMessage;
          _progress = 0.0;
          _hasError = true;
        });
        debugPrint("Scanning Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      color: _hasError ? theme.colorScheme.error : AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: _hasError
                        ? Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 32)
                        : const CircularProgressIndicator(
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
                style: AppTheme.inter(
                  color: theme.textTheme.bodyMedium?.color,
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
                  style: AppTheme.sourceCodePro( // Monospace for technical feel
                    color: _hasError ? theme.colorScheme.error : theme.textTheme.bodyLarge?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Progress Bar or Retry Action
              if (_hasError)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _startScanningSequence,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('RETRY CONNECTION'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: theme.cardTheme.color,
                    color: AppTheme.primaryColor,
                    minHeight: 4,
                  ),
                ),

              const Spacer(),
              
              // Footer
              Center(
                child: Text(
                  'ID: 84-F9-22-01', // Mock Session ID
                  style: AppTheme.inter(
                    color: theme.disabledColor,
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
