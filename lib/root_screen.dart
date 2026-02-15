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

    return Scaffold(
      body: StackedMenuNavigation(
        rootMenu: rootMenu,
        contentBuilder: (Menu leaf) => _LeafContent(menu: leaf),
        placeholder: Container(color: Colors.red),
      ),
    );
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
