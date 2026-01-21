part of 'package:drivererpapp/screens/module/common/tab_settings_screen.dart';

mixin _TabSettingsDetailMixin on State<TabSettingsScreen> {
  Widget _buildDetailTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHOOSE LAYOUT', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          _buildDetailTemplateOption(
            'standard',
            'Standard Card',
            'Classic centered header with rounded borders',
            Icons.crop_16_9_rounded,
          ),
          const SizedBox(height: 12),
          _buildDetailTemplateOption(
            'modern',
            'Modern Visual',
            'Full-width image header with integrated titles',
            Icons.view_quilt_rounded,
          ),
          const SizedBox(height: 32),

          Text('HEADER CONFIGURATION', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),

          // Conditional Title
          SwitchListTile(
            title: const Text('Conditional Title'),
            subtitle: const Text('Change title based on record data'),
            value: (this as _TabSettingsScreenState)._useConditionalTitle,
            activeColor: this.widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => this.setState(() => (this as _TabSettingsScreenState)._useConditionalTitle = val),
          ),
            if ((this as _TabSettingsScreenState)._useConditionalTitle) ...[
            const SizedBox(height: 8),
            (this as _TabSettingsScreenState)._buildColumnDropdown('Condition (e.g. Is Individual?)', (this as _TabSettingsScreenState)._titleLogicCondition, (val) => this.setState(() => (this as _TabSettingsScreenState)._titleLogicCondition = val)),
            const SizedBox(height: 12),
            Row(
              children: [
                  Expanded(child: (this as _TabSettingsScreenState)._buildColumnDropdown('If True', (this as _TabSettingsScreenState)._titleLogicTruthy, (val) => this.setState(() => (this as _TabSettingsScreenState)._titleLogicTruthy = val))),
                const SizedBox(width: 12),
                  Expanded(child: (this as _TabSettingsScreenState)._buildColumnDropdown('If False', (this as _TabSettingsScreenState)._titleLogicFalsy, (val) => this.setState(() => (this as _TabSettingsScreenState)._titleLogicFalsy = val))),
              ],
            ),
          ] else
            (this as _TabSettingsScreenState)._buildColumnDropdown('Main Title', (this as _TabSettingsScreenState)._detailTitleKey, (val) => this.setState(() => (this as _TabSettingsScreenState)._detailTitleKey = val)),

          const SizedBox(height: 24),

          // Conditional Subtitle
          SwitchListTile(
            title: const Text('Conditional Subtitle'),
            subtitle: const Text('Change subtitle based on record data'),
            value: (this as _TabSettingsScreenState)._useConditionalSubtitle,
            activeColor: this.widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => this.setState(() => (this as _TabSettingsScreenState)._useConditionalSubtitle = val),
          ),
            if ((this as _TabSettingsScreenState)._useConditionalSubtitle) ...[
            const SizedBox(height: 8),
            (this as _TabSettingsScreenState)._buildColumnDropdown('Condition Column', (this as _TabSettingsScreenState)._subtitleLogicCondition, (val) => this.setState(() => (this as _TabSettingsScreenState)._subtitleLogicCondition = val)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: (this as _TabSettingsScreenState)._buildColumnDropdown('If True', (this as _TabSettingsScreenState)._subtitleLogicTruthy, (val) => this.setState(() => (this as _TabSettingsScreenState)._subtitleLogicTruthy = val))),
                const SizedBox(width: 12),
                Expanded(child: (this as _TabSettingsScreenState)._buildColumnDropdown('If False', (this as _TabSettingsScreenState)._subtitleLogicFalsy, (val) => this.setState(() => (this as _TabSettingsScreenState)._subtitleLogicFalsy = val))),
              ],
            ),
          ] else
            (this as _TabSettingsScreenState)._buildColumnDropdown('Subtitle', (this as _TabSettingsScreenState)._detailSubtitleKey, (val) => this.setState(() => (this as _TabSettingsScreenState)._detailSubtitleKey = val), isOptional: true),

          const SizedBox(height: 24),
          (this as _TabSettingsScreenState)._buildColumnDropdown('Header Image', (this as _TabSettingsScreenState)._detailImageKey, (val) => this.setState(() => (this as _TabSettingsScreenState)._detailImageKey = val), isOptional: true),

          const SizedBox(height: 32),
          Text('FIELD VISIBILITY', style: _sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Show All Fields'),
            subtitle: const Text('Automatically display all visible columns'),
            value: (this as _TabSettingsScreenState)._detailShowAll,
            activeColor: this.widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => this.setState(() => (this as _TabSettingsScreenState)._detailShowAll = val),
          ),

            if (!(this as _TabSettingsScreenState)._detailShowAll) ...[
            const SizedBox(height: 16),
            ...this.widget.tab.columns.where((c) => c.hidden != true).map((col) {
              return CheckboxListTile(
                title: Text(col.label, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                value: (this as _TabSettingsScreenState)._detailFields.contains(col.key),
                activeColor: this.widget.primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  this.setState(() {
                    if (val == true) {
                      (this as _TabSettingsScreenState)._detailFields.add(col.key);
                    } else {
                      (this as _TabSettingsScreenState)._detailFields.remove(col.key);
                    }
                  });
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailTemplateOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = (this as _TabSettingsScreenState)._selectedDetailTemplate == value;
    final theme = Theme.of(this.context);

    return InkWell(
      onTap: () => this.setState(() => (this as _TabSettingsScreenState)._selectedDetailTemplate = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? this.widget.primaryColor.withValues(alpha: 0.1) : theme.cardTheme.color,
          border: Border.all(
            color: isSelected ? this.widget.primaryColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? this.widget.primaryColor : theme.iconTheme.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.inter(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? this.widget.primaryColor : theme.textTheme.bodyLarge?.color,
                  )),
                  Text(subtitle, style: AppTheme.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  )),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: this.widget.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  TextStyle _sectionHeaderStyle(ThemeData theme) => AppTheme.inter(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
    letterSpacing: 1.2,
  );
}
