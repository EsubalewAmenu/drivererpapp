import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'workspace_selector_screen.dart';

class SystemScanningScreen extends StatefulWidget {
  const SystemScanningScreen({super.key});

  @override
  State<SystemScanningScreen> createState() => _SystemScanningScreenState();
}

class _SystemScanningScreenState extends State<SystemScanningScreen> {
  final List<String> _statusMessages = [
    "Establishing secure handshake...",
    "Scanning Drive for .drive_erp_manifest...",
    "Verifying cryptographic signatures...",
    "Validating data integrity...",
    "Syncing workspace configuration...",
    "System ready."
  ];

  int _currentIndex = 0;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startScanningSequence();
  }

  void _startScanningSequence() {
    const totalDuration = Duration(seconds: 3);
    const stepDuration = Duration(milliseconds: 600); // 3000ms / 5 steps

    Timer.periodic(stepDuration, (timer) {
      if (_currentIndex < _statusMessages.length - 1) {
        setState(() {
          _currentIndex++;
          _progress = (_currentIndex + 1) / _statusMessages.length;
        });
      } else {
        timer.cancel();
        // Navigate to WorkspaceSelector after a brief pause on "System ready"
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const WorkspaceSelectorScreen()),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Using dark theme for the "technical/terminal" feel, or consistent light theme?
    // The prompt mentions "High Trust" perception. Often technical scans look good in dark mode,
    // but if the rest is white, maybe stick to white.
    // However, the "Enterprise HUD" description earlier mentioned dark mode.
    // The Landing page was requested to be "Minimalist white".
    // Let's stick to the AppTheme.darkTheme for this "System" operation to give it a "Terminal/Backend" feel,
    // OR keep it consistent with the Landing page.
    // Given "High Trust" and "Technical status messages", a clean technical look is best.
    // Let's use the Dark theme for this specific "System" screen to contrast with the "Public" landing page,
    // implying we are now "inside" the system. Or maybe just consistent light.
    // Let's go with Dark for the "System" feel as per the original "Enterprise HUD" spec which was dark.

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
                      color: AppTheme.primaryColor.withOpacity(0.3),
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
                  _statusMessages[_currentIndex],
                  key: ValueKey<int>(_currentIndex),
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
