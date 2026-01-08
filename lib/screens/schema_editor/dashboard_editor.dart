import 'package:flutter/material.dart';
import 'package:drivererpapp/theme/app_theme.dart';
import '../../models/schema_models.dart';

class DashboardEditor extends StatelessWidget {
  final List<DashboardCard> cards;
  final VoidCallback onAddCard;
  final Function(int index) onDeleteCard;
  final Function(int index, DashboardCard card) onEditCard;

  const DashboardEditor({
    super.key,
    required this.cards,
    required this.onAddCard,
    required this.onDeleteCard,
    required this.onEditCard,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length + 1,
      itemBuilder: (context, index) {
        if (index == cards.length) {
          return _buildAddButton(context, 'Add Card', onAddCard);
        }
        return _buildCardEditor(context, cards[index], index);
      },
    );
  }

  Widget _buildCardEditor(BuildContext context, DashboardCard card, int index) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color ?? theme.cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(card.label, style: AppTheme.inter(fontWeight: FontWeight.w700, color: theme.textTheme.titleMedium?.color)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: theme.primaryColor,
                      onPressed: () => onEditCard(index, card),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                      onPressed: () => onDeleteCard(index),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.functions, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.formula,
                      style: AppTheme.sourceCodePro(color: theme.textTheme.bodyMedium?.color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, String label, VoidCallback onTap, {bool isSmall = false}) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: color, size: isSmall ? 16 : 24),
              const SizedBox(width: 8),
              Text(label, style: AppTheme.inter(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
