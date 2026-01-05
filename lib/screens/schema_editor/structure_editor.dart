import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/schema_models.dart';
import '../../theme/app_theme.dart';
import 'widgets/tab_editor_card.dart';
import 'dialogs/add_tab_dialog.dart';

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

  Widget _buildAddButton(String label, VoidCallback onTap, {bool isSmall = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryTextColor.withOpacity(0.3), style: BorderStyle.solid),
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
