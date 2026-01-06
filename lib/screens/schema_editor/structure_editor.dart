import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';
import 'widgets/tab_editor_card.dart';
import 'dialogs/add_tab_dialog.dart';
import 'dialogs/edit_tab_dialog.dart';

class StructureEditor extends StatefulWidget {
  final List<TabConfig> tabs;
  final Map<String, dynamic>? rawSettings;
  final Function(List<TabConfig>) onTabsChanged;

  const StructureEditor({
    super.key,
    required this.tabs,
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
      padding: const EdgeInsets.all(16),
      itemCount: widget.tabs.length + 1,
      itemBuilder: (context, index) {
        if (index == widget.tabs.length) {
          return _buildAddButton('Add New Tab', () {
            _showAddTabDialog();
          });
        }
        return TabEditorCard(
          tab: widget.tabs[index],
          rawSettings: widget.rawSettings,
          onTabChanged: (updatedTab) {
            final newTabs = List<TabConfig>.from(widget.tabs);
            newTabs[index] = updatedTab;
            widget.onTabsChanged(newTabs);
          },
          onEdit: () => _showEditTabDialog(widget.tabs[index]),
          onDelete: () => _confirmDeleteTab(widget.tabs[index]),
        );
      },
    );
  }

  Future<void> _showAddTabDialog() async {
    final newTab = await showDialog<TabConfig>(
      context: context,
      builder: (context) => const AddTabDialog(),
    );

    if (newTab != null) {
      final newTabs = List<TabConfig>.from(widget.tabs)..add(newTab);
      widget.onTabsChanged(newTabs);
    }
  }

  Future<void> _showEditTabDialog(TabConfig tab) async {
    final updatedTab = await showDialog<TabConfig>(
      context: context,
      builder: (context) => EditTabDialog(tab: tab),
    );

    if (updatedTab != null) {
      final newTabs = List<TabConfig>.from(widget.tabs);
      final index = newTabs.indexOf(tab);
      if (index != -1) {
        newTabs[index] = updatedTab;
        widget.onTabsChanged(newTabs);
      }
    }
  }

  void _confirmDeleteTab(TabConfig tab) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Tab', style: TextStyle(color: AppTheme.textColor)),
        content: Text('Are you sure you want to delete "${tab.label}"? This cannot be undone.', style: const TextStyle(color: AppTheme.secondaryTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newTabs = List<TabConfig>.from(widget.tabs)..remove(tab);
              widget.onTabsChanged(newTabs);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap, {bool isSmall = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryTextColor.withValues(alpha: 0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppTheme.secondaryTextColor, size: isSmall ? 16 : 24),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
