import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'menu.dart';
import 'navigation_provider.dart';

/// One level in the stacked menu: shows title, optional back button, and list of items.
/// Tapping an item with children pushes the next level (slide right); back pops (slide left).
class MenuLevelScreen extends ConsumerWidget {
  const MenuLevelScreen({
    super.key,
    required this.menu,
    required this.showBackButton,
    this.selectedLeaf,
  });

  final Menu menu;
  final bool showBackButton;
  final Menu? selectedLeaf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(navigationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => notifier.goBack(),
              )
            : null,
        title: Text(menu.title),
      ),
      body: menu.items.isEmpty
          ? const Center(child: Text('No sub-items'))
          : ListView.builder(
              itemCount: menu.items.length,
              itemBuilder: (context, index) {
                final item = menu.items[index];
                final hasChildren = item.items.isNotEmpty;
                final isSelectedLeaf = selectedLeaf?.id == item.id;
                return ListTile(
                  selected: isSelectedLeaf,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: isSelectedLeaf ? FontWeight.w600 : null,
                    ),
                  ),
                  trailing: hasChildren
                      ? const Icon(Icons.chevron_right, color: Colors.grey)
                      : null,
                  onTap: () {
                    notifier.selectMenu(item);
                  },
                );
              },
            ),
    );
  }
}
