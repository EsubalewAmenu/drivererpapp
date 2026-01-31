part of 'package:drivererpapp/screens/module/common/tab_settings_screen.dart';

mixin _TabSettingsListMixin on State<TabSettingsScreen> {
  Widget _buildDisplayTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHOOSE TEMPLATE', style: (this as _TabSettingsScreenState)._sectionHeaderStyle(theme)),
          const SizedBox(height: 16),
          _buildTemplateOption(
            'high_density',
            'High Density',
            'Compact rows with status indicator',
            Icons.reorder_rounded,
          ),
          const SizedBox(height: 12),
          _buildTemplateOption(
            'standard',
            'Standard Card',
            'Detailed cards with trailing info and labels',
            Icons.view_agenda_rounded,
          ),
          const SizedBox(height: 32),

            Text('COLUMN MAPPING', style: (this as _TabSettingsScreenState)._sectionHeaderStyle(theme)),
          const SizedBox(height: 16),

          // Conditional Title (List)
          SwitchListTile(
            title: const Text('Conditional Title'),
            subtitle: const Text('Change row title based on record data'),
            value: (this as _TabSettingsScreenState)._listUseConditionalTitle,
            activeThumbColor: widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => (this as _TabSettingsScreenState)._listUseConditionalTitle = val),
          ),
            if ((this as _TabSettingsScreenState)._listUseConditionalTitle) ...[
            const SizedBox(height: 8),
            _buildColumnDropdown('Condition (e.g. Is Individual?)', (this as _TabSettingsScreenState)._listTitleLogicCondition, (val) => setState(() => (this as _TabSettingsScreenState)._listTitleLogicCondition = val)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildColumnDropdown('If True', (this as _TabSettingsScreenState)._listTitleLogicTruthy, (val) => setState(() => (this as _TabSettingsScreenState)._listTitleLogicTruthy = val))),
                const SizedBox(width: 12),
                Expanded(child: _buildColumnDropdown('If False', (this as _TabSettingsScreenState)._listTitleLogicFalsy, (val) => setState(() => (this as _TabSettingsScreenState)._listTitleLogicFalsy = val))),
              ],
            ),
          ] else ...[
            _buildColumnDropdown('Title Column', (this as _TabSettingsScreenState)._titleKey, (val) => setState(() => (this as _TabSettingsScreenState)._titleKey = val)),
          ],

          const SizedBox(height: 16),

          // Conditional Subtitle (List)
          SwitchListTile(
            title: const Text('Conditional Subtitle'),
            subtitle: const Text('Change row subtitle based on record data'),
            value: (this as _TabSettingsScreenState)._listUseConditionalSubtitle,
            activeThumbColor: widget.primaryColor,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => (this as _TabSettingsScreenState)._listUseConditionalSubtitle = val),
          ),
            if ((this as _TabSettingsScreenState)._listUseConditionalSubtitle) ...[
            const SizedBox(height: 8),
            _buildColumnDropdown('Condition', (this as _TabSettingsScreenState)._listSubtitleLogicCondition, (val) => setState(() => (this as _TabSettingsScreenState)._listSubtitleLogicCondition = val)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildColumnDropdown('If True', (this as _TabSettingsScreenState)._listSubtitleLogicTruthy, (val) => setState(() => (this as _TabSettingsScreenState)._listSubtitleLogicTruthy = val))),
                const SizedBox(width: 12),
                Expanded(child: _buildColumnDropdown('If False', (this as _TabSettingsScreenState)._listSubtitleLogicFalsy, (val) => setState(() => (this as _TabSettingsScreenState)._listSubtitleLogicFalsy = val))),
              ],
            ),
          ] else ...[
            _buildColumnDropdown('Subtitle Column', (this as _TabSettingsScreenState)._subtitleKey, (val) => setState(() => (this as _TabSettingsScreenState)._subtitleKey = val)),
          ],

          if ((this as _TabSettingsScreenState)._selectedTemplate == 'standard') ...[
            const SizedBox(height: 16),
            // Conditional Trailing (List)
            SwitchListTile(
              title: const Text('Conditional Trailing (Badge)'),
              subtitle: const Text('Change badge based on record data'),
              value: (this as _TabSettingsScreenState)._listUseConditionalTrailing,
              activeThumbColor: widget.primaryColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => (this as _TabSettingsScreenState)._listUseConditionalTrailing = val),
            ),
            if ((this as _TabSettingsScreenState)._listUseConditionalTrailing) ...[
              const SizedBox(height: 8),
              _buildColumnDropdown('Condition', (this as _TabSettingsScreenState)._listTrailingLogicCondition, (val) => setState(() => (this as _TabSettingsScreenState)._listTrailingLogicCondition = val)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildColumnDropdown('If True', (this as _TabSettingsScreenState)._listTrailingLogicTruthy, (val) => setState(() => (this as _TabSettingsScreenState)._listTrailingLogicTruthy = val))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildColumnDropdown('If False', (this as _TabSettingsScreenState)._listTrailingLogicFalsy, (val) => setState(() => (this as _TabSettingsScreenState)._listTrailingLogicFalsy = val))),
                ],
              ),
            ] else ...[
              _buildColumnDropdown('Trailing Column (Badge)', (this as _TabSettingsScreenState)._trailingKey, (val) => setState(() => (this as _TabSettingsScreenState)._trailingKey = val), isOptional: true),
            ],
            const SizedBox(height: 32),
            Text('EXTRA DETAILS', style: (this as _TabSettingsScreenState)._sectionHeaderStyle(theme)),
            const SizedBox(height: 8),
            ...widget.tab.columns.map((col) {
              final isTitleKey = !(this as _TabSettingsScreenState)._listUseConditionalTitle && col.key == (this as _TabSettingsScreenState)._titleKey;
              final isSubtitleKey = !(this as _TabSettingsScreenState)._listUseConditionalSubtitle && col.key == (this as _TabSettingsScreenState)._subtitleKey;
              final isTrailingKey = !(this as _TabSettingsScreenState)._listUseConditionalTrailing && col.key == (this as _TabSettingsScreenState)._trailingKey;

              if (isTitleKey || isSubtitleKey || isTrailingKey) {
                return const SizedBox.shrink();
              }
              return CheckboxListTile(
                title: Text(col.label, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                value: (this as _TabSettingsScreenState)._detailKeys.contains(col.key),
                activeColor: widget.primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                    setState(() {
                    if (val == true) {
                      (this as _TabSettingsScreenState)._detailKeys.add(col.key);
                    } else {
                      (this as _TabSettingsScreenState)._detailKeys.remove(col.key);
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

  Widget _buildTemplateOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = (this as _TabSettingsScreenState)._selectedTemplate == value;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => (this as _TabSettingsScreenState)._selectedTemplate = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryColor.withValues(alpha: 0.1) : theme.cardTheme.color,
          border: Border.all(
            color: isSelected ? widget.primaryColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? widget.primaryColor : theme.iconTheme.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.inter(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? widget.primaryColor : theme.textTheme.bodyLarge?.color,
                  )),
                  Text(subtitle, style: AppTheme.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  )),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: widget.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnDropdown(String label, String? value, Function(String?) onChanged, {bool isOptional = false}) {
    final theme = Theme.of(context);

    // Check if the current value exists in the columns
    final bool valueExists = value == null || widget.tab.columns.any((c) => c.key == value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardTheme.color,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          items: [
            if (isOptional) const DropdownMenuItem(value: null, child: Text('None')),
            ...widget.tab.columns.map((col) => DropdownMenuItem(
              value: col.key,
              child: Text(col.label),
            )),
            if (!valueExists)
              DropdownMenuItem(
                value: value,
                child: Text('$value (Missing)', style: const TextStyle(color: Colors.red)),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
