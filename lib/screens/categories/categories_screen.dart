import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/category_icons.dart';
import 'category_edit_dialog.dart';

/// Settings → Manage categories: grid of expense and income categories.
/// Tap one to rename / change icon and colour; + adds a new one.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));

  @override
  Widget build(BuildContext context) {
    final all = context.watch<TransactionProvider>().allCategories;
    final expense = all.where((c) => !c.isIncome).toList();
    final income = all.where((c) => c.isIncome).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_categories',
        onPressed: () => showCategoryEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: CustomScrollView(
        slivers: [
          _header(context, 'Expense'),
          _grid(expense),
          _header(context, 'Income'),
          _grid(income),
          const SliverToBoxAdapter(child: SizedBox(height: 88)), // FAB space
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      );

  // A "sliver" is a piece of a scrolling area; SliverGrid is a grid that
  // scrolls together with the headers above and below it.
  Widget _grid(List<CategoryModel> items) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 110,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _CategoryTile(category: items[i]),
        ),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCategoryEditDialog(context, existing: category),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(iconFor(category.icon), color: color),
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
