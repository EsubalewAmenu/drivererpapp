import 'package:flutter/material.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import '../../models/schema_models.dart';
import 'widgets/tab_editor_card.dart';
import 'dialogs/add_tab_dialog.dart';
import 'dialogs/edit_tab_dialog.dart';

class StructureEditor extends StatefulWidget {
  final List<CollectionSchema> collections;
  final Map<String, dynamic>? rawSettings;
  final Function(List<CollectionSchema>) onTabsChanged;

  const StructureEditor({
    super.key,
    required this.collections,
    required this.rawSettings,
    required this.onTabsChanged,
  });

  @override
  State<StructureEditor> createState() => _StructureEditorState();
}

class _StructureEditorState extends State<StructureEditor> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: widget.collections.length + 1,
      itemBuilder: (context, index) {
        if (index == widget.collections.length) {
          return _buildAddButton('Add collection', () {
            _showAddTabDialog();
          });
        }
        return TabEditorCard(
          tab: widget.collections[index],
          rawSettings: widget.rawSettings,
          onTabChanged: (updatedTab) {
            final newTabs = List<CollectionSchema>.from(widget.collections);
            newTabs[index] = updatedTab;
            widget.onTabsChanged(newTabs);
          },
          onEdit: () => _showEditTabDialog(widget.collections[index]),
          onDelete: () => _confirmDeleteTab(widget.collections[index]),
        );
      },
    );
  }

  Future<void> _showAddTabDialog() async {
    final newTab = await showDialog<CollectionSchema>(
      context: context,
      builder: (context) => const AddTabDialog(),
    );

    if (newTab != null) {
      final newTabs = List<CollectionSchema>.from(widget.collections)
        ..add(newTab);
      widget.onTabsChanged(newTabs);
    }
  }

  Future<void> _showEditTabDialog(CollectionSchema tab) async {
    final updatedTab = await showDialog<CollectionSchema>(
      context: context,
      builder: (context) => EditTabDialog(tab: tab),
    );

    if (updatedTab != null) {
      final newTabs = List<CollectionSchema>.from(widget.collections);
      final index = newTabs.indexOf(tab);
      if (index != -1) {
        newTabs[index] = updatedTab;
        widget.onTabsChanged(newTabs);
      }
    }
  }

  void _confirmDeleteTab(CollectionSchema tab) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardTheme.color ?? theme.cardColor,
          title: Text(
            'Delete collection',
            style: TextStyle(color: theme.textTheme.titleLarge?.color),
          ),
          content: Text(
            'Are you sure you want to delete "${tab.label}"? This cannot be undone.',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newTabs = List<CollectionSchema>.from(widget.collections)
                  ..remove(tab);
                widget.onTabsChanged(newTabs);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddButton(
    String label,
    VoidCallback onTap, {
    bool isSmall = false,
  }) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: color, size: isSmall ? 16 : 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTheme.inter(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
