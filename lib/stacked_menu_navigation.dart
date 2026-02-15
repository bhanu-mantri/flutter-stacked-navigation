import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'menu.dart';

/// Controller for [StackedMenuNavigation]. Holds navigation state and mutates
/// the supplied [root] menu's [Menu.isActive] to represent the current path.
class StackedMenuController {
  StackedMenuController({required Menu root, VoidCallback? onNavigate})
      : _root = root,
        _onNavigate = onNavigate;

  Menu _root;
  Menu? _selectedLeaf;
  VoidCallback? _onNavigate;

  Menu get root => _root;
  Menu? get selectedLeaf => _selectedLeaf;

  void attachRoot(Menu root) {
    _root = root;
    _onNavigate?.call();
  }

  void _notify() => _onNavigate?.call();

  /// Path from root to the current (deepest active) menu. Does not include leaf.
  List<Menu> getCurrentPath() {
    final path = <Menu>[_root];
    Menu cur = _root;
    while (true) {
      Menu? next;
      for (final item in cur.items) {
        if (item.isActive) {
          next = item;
          break;
        }
      }
      if (next == null) break;
      path.add(next);
      cur = next;
    }
    return path;
  }

  void selectMenu(Menu menu) {
    if (menu.items.isEmpty) {
      _selectedLeaf = menu;
      _notify();
      return;
    }
    for (final item in menu.parent!.items) {
      item.isActive = false;
    }
    menu.isActive = true;
    _notify();
  }

  void goBack() {
    final path = getCurrentPath();
    if (path.length <= 1) return;
    path.last.isActive = false;
    final parent = path[path.length - 2];
    if (parent.parent != null) {
      for (final item in parent.parent!.items) {
        item.isActive = false;
      }
      parent.isActive = true;
    }
    _notify();
  }
}

/// Reusable stacked menu navigation: left panel with slide-in menu levels,
/// right panel shows selected leaf content.
///
/// Supply [rootMenu] dynamically (e.g. from a provider or async builder).
/// Use [contentBuilder] to build content for the selected leaf; if null,
/// a default placeholder is shown.
class StackedMenuNavigation extends StatefulWidget {
  const StackedMenuNavigation({
    super.key,
    required this.rootMenu,
    this.contentBuilder,
    this.menuWidth = 250,
    this.placeholder,
  });

  /// Root of the menu tree. Can be replaced anytime; controller will use the new root.
  final Menu rootMenu;

  /// Builds the content area when a leaf [Menu] is selected. If null, [placeholder] is used.
  final Widget Function(Menu leaf)? contentBuilder;

  /// Width of the left menu panel.
  final double menuWidth;

  /// Shown in the content area when no leaf is selected. Defaults to a simple container.
  final Widget? placeholder;

  @override
  State<StackedMenuNavigation> createState() => _StackedMenuNavigationState();
}

class _StackedMenuNavigationState extends State<StackedMenuNavigation> {
  late StackedMenuController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StackedMenuController(
      root: widget.rootMenu,
      onNavigate: () => setState(() {}),
    );
  }

  @override
  void didUpdateWidget(StackedMenuNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootMenu != widget.rootMenu) {
      _controller.attachRoot(widget.rootMenu);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _controller.getCurrentPath();
    final selectedLeaf = _controller.selectedLeaf;

    final pages = <Page<void>>[];
    for (var i = 0; i < path.length; i++) {
      final menu = path[i];
      pages.add(
        CustomTransitionPage<void>(
          key: ValueKey(menu.id),
          child: _MenuLevelScreen(
            menu: menu,
            showBackButton: i > 0,
            selectedLeaf: selectedLeaf,
            controller: _controller,
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offsetAnimation = Tween<Offset>(
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

    final content = selectedLeaf != null
        ? (widget.contentBuilder != null
            ? widget.contentBuilder!(selectedLeaf)
            : _defaultLeafContent(context, selectedLeaf))
        : (widget.placeholder ?? _defaultPlaceholder(context));

    return Row(
      children: [
        SizedBox(
          width: widget.menuWidth,
          child: Navigator(
            pages: pages,
            onPopPage: (route, result) {
              if (pages.length <= 1) return false;
              _controller.goBack();
              return true;
            },
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _defaultLeafContent(BuildContext context, Menu leaf) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Text(
          leaf.title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
  }
}

class _MenuLevelScreen extends StatelessWidget {
  const _MenuLevelScreen({
    required this.menu,
    required this.showBackButton,
    required this.selectedLeaf,
    required this.controller,
  });

  final Menu menu;
  final bool showBackButton;
  final Menu? selectedLeaf;
  final StackedMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: controller.goBack,
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
                  onTap: () => controller.selectMenu(item),
                );
              },
            ),
    );
  }
}
