import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/erp_controller.dart';
import 'media_field.dart';

class DynamicFileField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  const DynamicFileField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    child: Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: Text(
            value == null || value!.isEmpty ? 'Choose file' : 'Replace file',
          ),
          onPressed: () async {
            try {
              final scope = AttachmentScope.of(context);
              final erp = context.read<ErpController>();
              if (scope == null) return;
              final picked = await FilePicker.platform.pickFiles(
                withData: true,
              );
              if (picked == null) return;
              final file = picked.files.single;
              final id = await erp.api.upload(
                company: erp.company!.id,
                module: scope.moduleId,
                collection: scope.collection,
                recordId: scope.recordId,
                name: file.name,
                bytes: file.bytes!,
              );
              if (context.mounted) onChanged(id);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
        ),
        if (value?.isNotEmpty == true)
          IconButton(
            tooltip: 'Remove reference',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.clear),
          ),
      ],
    ),
  );
}
