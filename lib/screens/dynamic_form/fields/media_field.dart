import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/schema_models.dart';
import '../../../providers/erp_controller.dart';
import '../../../services/backend/backend_session.dart';

class AttachmentScope extends InheritedWidget {
  final String moduleId;
  final String collection;
  final String recordId;
  const AttachmentScope({
    super.key,
    required this.moduleId,
    required this.collection,
    required this.recordId,
    required super.child,
  });
  static AttachmentScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AttachmentScope>();
  @override
  bool updateShouldNotify(AttachmentScope old) =>
      old.recordId != recordId ||
      old.collection != collection ||
      old.moduleId != moduleId;
}

class DynamicMediaField extends StatefulWidget {
  final FieldDefinition column;
  final String? value;
  final Color primaryColor;
  final ValueChanged<String> onChanged;
  final String type;
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
  bool loading = false;
  Future<void> _pick(ImageSource source) async {
    final scope = AttachmentScope.of(context);
    final erp = context.read<ErpController>();
    if (scope == null || erp.company == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 85,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() => loading = true);
      final id = await erp.api.upload(
        company: erp.company!.id,
        module: scope.moduleId,
        collection: scope.collection,
        recordId: scope.recordId,
        name: file.name,
        bytes: await file.readAsBytes(),
      );
      if (mounted) widget.onChanged(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _choose() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select image source'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) await _pick(choice);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.value?.isNotEmpty == true;
    final url = hasImage ? BackendSession.mediaUrl(widget.value!) : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.column.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        if (widget.type == 'scanner')
          TextFormField(
            initialValue: widget.value,
            decoration: const InputDecoration(
              labelText: 'Barcode or scanned value',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.onChanged,
          )
        else if (loading)
          const LinearProgressIndicator()
        else
          InkWell(
            onTap: widget.column.readonly == true ? null : _choose,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.primaryColor.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasImage
                  ? Image.network(
                      url,
                      headers: BackendSession.mediaHeaders(url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, e, s) =>
                          const Center(child: Icon(Icons.broken_image)),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded),
                        SizedBox(height: 8),
                        Text('Tap to pick or capture image'),
                      ],
                    ),
            ),
          ),
        if (hasImage && widget.column.readonly != true)
          TextButton.icon(
            onPressed: () => widget.onChanged(''),
            icon: const Icon(Icons.clear),
            label: const Text('Remove reference'),
          ),
      ],
    );
  }
}
