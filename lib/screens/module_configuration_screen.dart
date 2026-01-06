import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../providers/workspace_provider.dart';
import 'dashboard_screen.dart';

class ModuleConfigurationScreen extends StatefulWidget {
  final Map<String, String> moduleInfo;

  const ModuleConfigurationScreen({super.key, required this.moduleInfo});

  @override
  State<ModuleConfigurationScreen> createState() => _ModuleConfigurationScreenState();
}

class _ModuleConfigurationScreenState extends State<ModuleConfigurationScreen> {
  bool _isLoading = true;
  bool _isActivating = false;
  Map<String, dynamic>? _moduleJson;
  final Map<String, dynamic> _formValues = {};

  @override
  void initState() {
    super.initState();
    _loadModuleConfig();
  }

  Future<void> _loadModuleConfig() async {
    try {
      final fileName = widget.moduleInfo['name']!.toLowerCase();
      // Try to load the specific JSON for the module
      final jsonString = await rootBundle.loadString('assets/erp_modules/$fileName.json');
      final json = jsonDecode(jsonString);
      
      setState(() {
        _moduleJson = json;
        _isLoading = false;
        
        // Initialize form values from settings
        if (json['settings'] != null) {
          final settings = json['settings'] as Map<String, dynamic>;
          settings.forEach((key, value) {
            if (value is Map && value.containsKey('value')) {
              _formValues[key] = value['value'];
            }
          });
        } else {
           _formValues['name'] = widget.moduleInfo['name'];
        }
      });
    } catch (e) {
      // Fallback if JSON not found
      setState(() {
        _isLoading = false;
        _formValues['name'] = widget.moduleInfo['name'];
      });
      debugPrint('Error loading module config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(widget.moduleInfo['color']!.replaceAll('#', '0xFF')));
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CONFIGURE ${widget.moduleInfo['name']!.toUpperCase()}',
          style: GoogleFonts.inter(
            color: AppTheme.textColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customize your module',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adjust the settings below to fit your business needs.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _buildFormFields(color),
                        ),
                      ),
                    ),

                    // Activate Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isActivating ? null : _activateModule,
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isActivating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'COMPLETE SETUP',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildFormFields(Color color) {
    if (_moduleJson == null || _moduleJson!['settings'] == null) {
      return [
        _buildTextField('Module Name', 'name', color),
      ];
    }

    final settings = _moduleJson!['settings'] as Map<String, dynamic>;
    return settings.entries.map((entry) {
      final key = entry.key;
      final field = entry.value as Map<String, dynamic>;
      final label = field['label'] ?? key;
      final type = field['type'] ?? 'text';
      final dependsOn = field['dependsOn'];

      // Check dependency
      if (dependsOn != null) {
        final dependencyValue = _formValues[dependsOn];
        // Assuming dependency is boolean true for now
        if (dependencyValue != true) {
          return const SizedBox.shrink();
        }
      }

      if (type == 'text') {
        return _buildTextField(label, key, color);
      } else if (type == 'select') {
        return _buildDropdownField(label, key, field['options'] ?? [], color);
      } else if (type == 'boolean') {
        return _buildSwitchField(label, key, color);
      } else if (type == 'list') {
        return _buildListField(label, key, color);
      }
      return const SizedBox.shrink();
    }).toList();
  }

  Widget _buildListField(String label, String key, Color color) {
    List<String> items = [];
    if (_formValues[key] is List) {
      items = List<String>.from(_formValues[key]);
    } else {
      items = [];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryTextColor,
                  letterSpacing: 1.0,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded, color: color),
                onPressed: () {
                  setState(() {
                    items.add("New Warehouse");
                    _formValues[key] = items;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: item,
                      onChanged: (value) {
                        items[index] = value;
                        _formValues[key] = items;
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textColor),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        items.removeAt(index);
                        _formValues[key] = items;
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String key, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryTextColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _formValues[key]?.toString(),
            onChanged: (value) => _formValues[key] = value,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String key, List<dynamic> options, Color color) {
     final List<String> strOptions = options.map((e) => e.toString()).toList();
     
     return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryTextColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _formValues[key] is String && strOptions.contains(_formValues[key]) 
                    ? _formValues[key] 
                    : (strOptions.isNotEmpty ? strOptions.first : null),
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: color),
                items: strOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _formValues[key] = newValue;
                  });
                },
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textColor,
                ),
                dropdownColor: AppTheme.surfaceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField(String label, String key, Color color) {
    final value = _formValues[key] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryTextColor,
              letterSpacing: 1.0,
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              setState(() {
                _formValues[key] = newValue;
              });
            },
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  Future<void> _activateModule() async {
    setState(() => _isActivating = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      
      if (authService.authClient == null || workspaceProvider.currentWorkspace == null) {
        throw Exception("Authentication or Workspace missing");
      }

      final driveService = DriveService(authService.authClient!);
      final workspaceId = workspaceProvider.currentWorkspace!.id!;
      
      final moduleName = _formValues['name'] ?? widget.moduleInfo['name']!;

      // Create the module folder in Drive
      await driveService.createWorkspace(workspaceId, moduleName);
      
      // In a real app, we would save the _formValues to a config file in the new folder.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$moduleName activated successfully!')),
        );
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error activating module: $e')),
        );
        setState(() => _isActivating = false);
      }
    }
  }
}
