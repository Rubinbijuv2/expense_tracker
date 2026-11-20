import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../utils/category_icons.dart';

/// Grid of category icons; tapping one selects it.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CategoryModel> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // shrinkWrap + no scrolling: the grid sits inside the page's ListView,
    // which already scrolls.
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        for (final c in categories)
          _CategoryItem(
            category: c,
            selected: c.id == selectedId,
            onTap: () => onSelected(c.id!),
            theme: theme,
          ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final CategoryModel category;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? color.withValues(alpha: 0.12) : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(iconFor(category.icon), color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
