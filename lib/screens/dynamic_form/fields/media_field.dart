import 'package:drivererpapp/providers/drive_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/workspace_provider.dart';
import '../../../services/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DynamicMediaField extends StatefulWidget {
  final ColumnConfig column;
  final String? value;
  final Color primaryColor;
  final Function(String) onChanged;
  final String type; // 'image', 'scanner', 'signature'
  final ModuleSchema? module;

  const DynamicMediaField({
    super.key,
    required this.column,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
    required this.type,
    this.module,
  });

  @override
  State<DynamicMediaField> createState() => _DynamicMediaFieldState();
}

class _DynamicMediaFieldState extends State<DynamicMediaField> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case 'image':
        return _buildImagePicker(context);
      case 'scanner':
        return _buildScanner(context);
      case 'signature':
        return _buildSignaturePad(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImagePicker(BuildContext context) {
    final theme = Theme.of(context);
    
    // Check if we have an image URL or ID
    final hasImage = widget.value != null && widget.value!.isNotEmpty;
    // Construct display URL (handling both raw ID and full URL)
    String? imageUrl;
    if (hasImage) {
      if (widget.value!.startsWith('http')) {
        imageUrl = widget.value;
      } else {
        imageUrl = 'https://drive.google.com/uc?export=view&id=${widget.value}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.column.readonly == true ? theme.dividerColor.withValues(alpha: 0.05) : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor, style: BorderStyle.solid),
          ),
          child: InkWell(
            onTap: (_isUploading || widget.column.readonly == true) ? null : () => _showImageSourceSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                if (hasImage && imageUrl != null)
                   ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 48, color: theme.disabledColor),
                            const SizedBox(height: 8),
                            Text('Failed to load image', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, size: 48, color: theme.textTheme.bodyMedium?.color),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to pick or capture image',
                          style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
                        ),
                      ],
                    ),
                  ),

                // Uploading Indicator Overlay
                if (_isUploading)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                
                // Edit/Remove buttons if image exists and not uploading
                if (hasImage && !_isUploading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          context, 
                          icon: Icons.edit_rounded, 
                          onTap: () => _showImageSourceSheet(context)
                        ),
                        if (widget.column.readonly != true) ...[
                          const SizedBox(width: 8),
                          _buildActionButton(
                            context, 
                            icon: Icons.delete_outline_rounded, 
                            color: Colors.red,
                            onTap: () => widget.onChanged(''), // Clear value
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasImage) 
           Padding(
             padding: const EdgeInsets.only(top: 8.0),
             child: Text(
               'Image saved to Drive.',
               style: TextStyle(fontSize: 12, color: Colors.green.shade600),
             ),
           ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required VoidCallback onTap, Color? color}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Theme.of(context).primaryColor, size: 20),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Image Source',
              style: AppTheme.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera_alt_rounded, color: widget.primaryColor),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Capture a new photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library_rounded, color: widget.primaryColor),
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Choose from existing photos'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image == null) return;
      
      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final extension = image.path.split('.').last.toLowerCase();
      final fileName = 'form_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      
      if (!mounted) return;

      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      
      DriveService? driveService;
      try {
        final driveProvider = Provider.of<DriveProvider>(context, listen: false);
        driveService = driveProvider.driveService;
      } catch (_) {
        debugPrint('DriveProvider not found in context.');
      }

      if (driveService == null) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed: Service unavailable')));
         }
         return;
      }

      final rootId = workspaceProvider.currentWorkspace?.id;
      if (rootId == null) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed: No active workspace')));
         }
         return;
      }
      
      String targetFolderId;
      if (widget.module != null) {
        // Create/Get 'module_files' folder inside module folder to keep things organized
        targetFolderId = await driveService.getOrCreateSubFolder(widget.module!.id, 'module_files');
      } else {
        targetFolderId = rootId;
      }

      final fileId = await driveService.uploadFile(
        targetFolderId, 
        fileName, 
        bytes, 
        mimeType: mimeType
      );
      
      await driveService.driveApi.permissions.create(
        drive.Permission()
          ..role = 'reader'
          ..type = 'anyone',
        fileId,
      );
      
      widget.onChanged(fileId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded successfully')));
      }

    } catch (e) {
      debugPrint('Error capturing/uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildScanner(BuildContext context) {
    final theme = Theme.of(context);
    final isReadonly = widget.column.readonly == true;
    // We need a controller to show the value in the text field part of the scanner
    final controller = TextEditingController(text: widget.value);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                readOnly: isReadonly,
                style: AppTheme.inter(color: isReadonly ? theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6) : theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isReadonly ? theme.dividerColor.withValues(alpha: 0.05) : theme.cardTheme.color,
                  hintText: 'Scan or enter code',
                  hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.qr_code, color: theme.textTheme.bodyMedium?.color),
                ),
                onChanged: widget.onChanged,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: isReadonly ? null : () {
                // Mock scanner action
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner started...')));
                // Simulate scan result
                final mockCode = 'SCAN-${DateTime.now().millisecondsSinceEpoch}';
                widget.onChanged(mockCode);
                controller.text = mockCode; // Update local controller
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isReadonly ? theme.dividerColor.withValues(alpha: 0.2) : widget.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isReadonly ? Colors.transparent : widget.primaryColor),
                ),
                child: Icon(Icons.qr_code_scanner_rounded, color: isReadonly ? theme.disabledColor : Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignaturePad(BuildContext context) {
    final theme = Theme.of(context);
    final isReadonly = widget.column.readonly == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: AppTheme.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isReadonly ? theme.dividerColor.withValues(alpha: 0.05) : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: InkWell(
            onTap: isReadonly ? null : () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature pad coming soon')));
            },
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                isReadonly ? 'View Signature' : 'Tap to sign',
                style: AppTheme.inter(color: isReadonly ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) : theme.textTheme.bodyMedium?.color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
