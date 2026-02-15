import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'menu.dart';
import 'menu_level_screen.dart';
import 'navigation_provider.dart';

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final notifier = ref.read(navigationProvider.notifier);
    final path = notifier.getCurrentPath();

    final pages = <Page<void>>[];
    for (var i = 0; i < path.length; i++) {
      final menu = path[i];
      pages.add(
        CustomTransitionPage<void>(
          key: ValueKey(menu.id),
          child: MenuLevelScreen(
            menu: menu,
            showBackButton: i > 0,
            selectedLeaf: navState.selectedLeaf,
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offsetAnimation =
                Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                );
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      );
    }

    final selectedLeaf = navState.selectedLeaf;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: Navigator(
              pages: pages,
              onPopPage: (route, result) {
                if (pages.length <= 1) return false;
                notifier.goBack();
                return true;
              },
            ),
          ),
          Expanded(
            child: selectedLeaf != null
                ? _LeafContent(menu: selectedLeaf)
                : Container(color: Colors.red),
          ),
        ],
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
