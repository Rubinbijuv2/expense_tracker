import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/category_icons.dart';

/// Colours a custom category can use.
const List<int> categoryColors = [
  0xFFEF6C00, 0xFF1E88E5, 0xFFD81B60, 0xFF6D4C41, 0xFF5E35B1, 0xFFE53935,
  0xFF00897B, 0xFF8E24AA, 0xFF43A047, 0xFF757575, 0xFFFDD835, 0xFF3949AB,
];

/// Add a category ([existing] null) or edit one. For default categories
/// only the icon and colour can change (no rename, no delete).
/// Custom categories can be renamed and deleted (if no transaction uses them).
Future<void> showCategoryEditDialog(BuildContext context,
    {CategoryModel? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CategoryEditDialog(existing: existing),
  );
}

class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({this.existing});

  final CategoryModel? existing;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _type = widget.existing?.type ?? 'expense';
  late String _icon = widget.existing?.icon ?? 'category';
  late int _color = widget.existing?.color ?? categoryColors.first;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final txns = context.read<TransactionProvider>();
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    if (txns.categoryNameTaken(name, _type, exceptId: widget.existing?.id)) {
      setState(() => _error = 'A category with this name already exists');
      return;
    }
    final category = (widget.existing ??
            CategoryModel(name: name, icon: _icon, color: _color, type: _type))
        .copyWith(name: name, icon: _icon, color: _color, type: _type);
    await txns.saveCategory(category);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final txns = context.read<TransactionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await txns.deleteCategory(widget.existing!);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Deleted "${widget.existing!.name}"'
          : 'Can\'t delete: some transactions or repeat payments use '
              'this category. Change them first.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final canDelete = existing != null && !existing.isDefault;

    return AlertDialog(
      title: Text(_isNew ? 'New category' : 'Edit category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: _isNew,
              maxLength: 20,
              // SMS category guessing finds default categories by name.
              readOnly: existing?.isDefault ?? false,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _error,
                helperText: (existing?.isDefault ?? false)
                    ? 'Default categories keep their name'
                    : null,
              ),
            ),
            if (_isNew) ...[
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Colour'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: c == _color
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Icon'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in categoryIcons.entries)
                  IconButton(
                    isSelected: entry.key == _icon,
                    style: IconButton.styleFrom(
                      backgroundColor: entry.key == _icon
                          ? Color(_color).withValues(alpha: 0.2)
                          : null,
                    ),
                    onPressed: () => setState(() => _icon = entry.key),
                    icon: Icon(entry.value,
                        color: entry.key == _icon ? Color(_color) : null),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (canDelete)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
