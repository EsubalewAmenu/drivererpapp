import 'package:flutter/material.dart';
import '../../../models/schema_models.dart';
import '../../../theme/app_theme.dart';

class ModuleFilterBar extends StatelessWidget {
  final TabConfig tab;
  final Color primaryColor;
  final TextEditingController searchController;
  final String? activeFilter;
  final List<QuickFilter> activeFilters;
  final bool showFilters;
  final Function(String?) onFilterChanged;
  final VoidCallback onOpenSettings;

  const ModuleFilterBar({
    super.key,
    required this.tab,
    required this.primaryColor,
    required this.searchController,
    required this.activeFilter,
    required this.activeFilters,
    required this.showFilters,
    required this.onFilterChanged,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(context),
        _buildQuickFilters(context),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              style: AppTheme.inter(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Search ${tab.label.toLowerCase()}...',
                hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                prefixIcon: Icon(Icons.search_rounded, color: theme.textTheme.bodyMedium?.color),
                filled: true,
                fillColor: theme.cardTheme.color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.tune_rounded, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters(BuildContext context) {
    if (!showFilters || activeFilters.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: activeFilters.length + 1, // +1 for "All"
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = activeFilter == null || activeFilter == 'all';
             return FilterChip(
              label: const Text('All'),
              selected: isSelected,
              onSelected: (_) => onFilterChanged('all'),
              backgroundColor: theme.cardTheme.color,
              selectedColor: primaryColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? primaryColor : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryColor : Colors.transparent,
                ),
              ),
              showCheckmark: false,
            );
          }
          
          final filter = activeFilters[index - 1];
          final isSelected = activeFilter == filter.key;

          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (_) => onFilterChanged(filter.key),
            backgroundColor: theme.cardTheme.color,
            selectedColor: primaryColor.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isSelected ? primaryColor : theme.textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    ); 
  }
}
