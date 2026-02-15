import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'menu.dart';
import 'menu_provider.dart';
import 'stacked_menu_navigation.dart';

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootMenu = ref.watch(menuProvider);
    // Pre-select a leaf. Works with dynamic menus (Mouse's children are loaded via onLoadChildren).
    // const initialPath = ['Products', 'Electronics', 'Mouse', 'Acer'];
    // For static-only leaves you can use initialSelectedLeaf: _findByTitlePath(rootMenu, ['Products', 'Speaker', 'Sony'])

    return Scaffold(
      body: StackedMenuNavigation(
        rootMenu: rootMenu,
        // initialSelectedLeafPath: initialPath,
        contentBuilder: (Menu leaf) => _LeafContent(menu: leaf),
        placeholder: Container(color: Colors.yellow),
        onLoadChildren: _loadChildren,
      ),
    );
  }

  /// Example: load a menu's children dynamically (e.g. from API).
  /// Use [menu.removeItems] first so refresh replaces the list with fresh data.
  static Future<void> _loadChildren(Menu menu) async {
    if (menu.title == 'Mouse') {
      menu.removeItems();
      await Future.delayed(const Duration(milliseconds: 800));
      menu.addMenu('Acer');
      menu.addMenu('Dell');
    } else if (menu.title == 'Recent') {
      menu.removeItems();
      await Future.delayed(const Duration(milliseconds: 600));
      menu.addMenu('Item A');
      menu.addMenu('Item B');
      menu.addMenu('Item C');
    }
    // Add more cases for other dynamic menus, or call a real API and add items.
  }
}

class _LeafContent extends StatelessWidget {
  const _LeafContent({required this.menu});

  final Menu menu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Text(
          menu.title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
