import 'package:flutter/material.dart';

import 'menu.dart';

/// A [Page] that uses a slide-from-right transition. Replaces go_router's CustomTransitionPage.
class _SlideTransitionPage extends Page<void> {
  const _SlideTransitionPage({required this.child, super.key});
  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder<void>(
      settings: this,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }
}

/// Controller for [StackedMenuNavigation]. Holds navigation state and mutates
/// the supplied [root] menu's [Menu.isActive] to represent the current path.
class StackedMenuController {
  StackedMenuController({
    required Menu root,
    Menu? initialSelectedLeaf,
    VoidCallback? onNavigate,
  }) : _root = root,
       _selectedLeaf = initialSelectedLeaf,
       _onNavigate = onNavigate {
    selectedLeafNotifier.value = initialSelectedLeaf;
  }

  Menu _root;
  Menu? _selectedLeaf;
  final VoidCallback? _onNavigate;

  /// Notifier so route content can rebuild when selection changes (Navigator reuses routes by key).
  final ValueNotifier<Menu?> selectedLeafNotifier = ValueNotifier<Menu?>(null);

  Menu get root => _root;
  Menu? get selectedLeaf => _selectedLeaf;

  void _setSelectedLeaf(Menu? leaf) {
    if (_selectedLeaf == leaf) return;
    _selectedLeaf = leaf;
    selectedLeafNotifier.value = leaf;
    _notify();
  }

  /// Sets the selected leaf (e.g. after resolving [initialSelectedLeafPath]).
  void setSelectedLeaf(Menu? leaf) {
    _setSelectedLeaf(leaf);
  }

  void attachRoot(Menu root) {
    _root = root;
    _onNavigate?.call();
  }

  void _notify() => _onNavigate?.call();

  /// Sets the menu stack path to [menu] (and its ancestors). Use to open to a
  /// given level, e.g. before setting [initialSelectedLeaf] so the stack shows
  /// the path to that leaf's parent.
  void setPathTo(Menu menu) {
    final path = <Menu>[];
    Menu? cur = menu;
    while (cur != null) {
      path.add(cur);
      cur = cur.parent;
    }
    final pathFromRoot = path.reversed.toList();
    for (final m in pathFromRoot) {
      if (m.parent != null) {
        for (final s in m.parent!.items) {
          s.isActive = false;
        }
      }
      m.isActive = true;
    }
    _notify();
  }

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
      _setSelectedLeaf(menu);
      _notify();
      return;
    }
    for (final item in menu.parent!.items) {
      item.isActive = false;
    }
    menu.isActive = true;
    _notify();
  }

  /// Pushes a menu level (opens the page) even when it has no children yet.
  /// Use before loading children so the transitioned page can show loading.
  void pushMenu(Menu menu) {
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
///
/// Use [onLoadChildren] to load a menu's children dynamically (e.g. from an API).
/// When the user taps a menu item that has no children, this is called; add
/// children with [menu.addMenu] then return. The menu will then open as a branch
/// or stay as a leaf if still empty.
///
/// Loaded children are cached (same [rootMenu] tree, mutated in place). To fetch
/// fresh data: use the refresh button on the menu level AppBar (when [onLoadChildren]
/// is set), or set [Menu.loadChildrenEveryTime] on specific items. In your loader,
/// call [Menu.removeItems] before adding new items so the list is replaced, not appended.
///
/// Use [initialSelectedLeaf] or [initialSelectedLeafPath] to pre-select a leaf.
/// The stack opens to that leaf's parent and the content panel shows that leaf.
/// [initialSelectedLeafPath] works with dynamically loaded items (e.g. Products >
/// Electronics > Mouse > Acer): children are loaded via [onLoadChildren] when needed.
/// Back works as usual.
class StackedMenuNavigation extends StatefulWidget {
  const StackedMenuNavigation({
    super.key,
    required this.rootMenu,
    this.initialSelectedLeaf,
    this.initialSelectedLeafPath,
    this.contentBuilder,
    this.menuWidth = 250,
    this.placeholder,
    this.onLoadChildren,
  });

  /// Root of the menu tree. Can be replaced anytime; controller will use the new root.
  final Menu rootMenu;

  /// If set, opens the stack to this leaf's parent and shows this leaf's content.
  /// Must be a [Menu] already in the [rootMenu] tree (e.g. static leaf like Sony).
  final Menu? initialSelectedLeaf;

  /// Path of menu titles from root's children to the leaf (e.g. ['Products', 'Electronics', 'Mouse', 'Acer']).
  /// Use for leaves under dynamically loaded menus: [onLoadChildren] is called for each level that has no children yet.
  /// Ignored if [initialSelectedLeaf] is set.
  final List<String>? initialSelectedLeafPath;

  /// Builds the content area when a leaf [Menu] is selected. If null, [placeholder] is used.
  final Widget Function(Menu leaf)? contentBuilder;

  /// Width of the left menu panel.
  final double menuWidth;

  /// Shown in the content area when no leaf is selected. Defaults to a simple container.
  final Widget? placeholder;

  /// Called when the user taps a menu item that has no children (or every time for
  /// items with [Menu.loadChildrenEveryTime] true). Load data (e.g. from API) and
  /// add children via [menu.addMenu]. Return when done; the item will then open as
  /// a branch or leaf. Call [Menu.removeItems] before adding when refetching.
  final Future<void> Function(Menu menu)? onLoadChildren;

  @override
  State<StackedMenuNavigation> createState() => _StackedMenuNavigationState();
}

class _StackedMenuNavigationState extends State<StackedMenuNavigation> {
  late StackedMenuController _controller;
  Menu? _loadingMenu;

  @override
  void initState() {
    super.initState();
    _controller = StackedMenuController(
      root: widget.rootMenu,
      initialSelectedLeaf: widget.initialSelectedLeaf,
      onNavigate: () => setState(() {}),
    );
    if (widget.initialSelectedLeafPath != null &&
        widget.initialSelectedLeafPath!.isNotEmpty &&
        widget.onLoadChildren != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveInitialLeafPath();
      });
    } else if (widget.initialSelectedLeaf?.parent != null) {
      _controller.setPathTo(widget.initialSelectedLeaf!.parent!);
    }
  }

  /// Resolves [initialSelectedLeafPath] by walking the tree and loading dynamic children when needed.
  Future<void> _resolveInitialLeafPath() async {
    final path = widget.initialSelectedLeafPath!;
    final loadChildren = widget.onLoadChildren!;
    Menu cur = widget.rootMenu;
    for (final name in path) {
      Menu? next;
      for (final m in cur.items) {
        if (m.title == name) {
          next = m;
          break;
        }
      }
      if (next == null && cur.loadsChildrenDynamically && cur.items.isEmpty) {
        await loadChildren(cur);
        for (final m in cur.items) {
          if (m.title == name) {
            next = m;
            break;
          }
        }
      }
      if (next == null || !mounted) return;
      cur = next;
    }
    if (!mounted) return;
    if (cur.parent != null) {
      _controller.setPathTo(cur.parent!);
    }
    _controller.setSelectedLeaf(cur);
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
      final isTopPage = i == path.length - 1;
      pages.add(
        _SlideTransitionPage(
          key: ValueKey(menu.id),
          child: _MenuLevelScreen(
            menu: menu,
            showBackButton: i > 0,
            canPopToParent: isTopPage && path.length > 1,
            selectedLeafNotifier: _controller.selectedLeafNotifier,
            controller: _controller,
            onLoadChildren: widget.onLoadChildren,
            loadingMenu: _loadingMenu,
            onLoadingComplete: () => setState(() => _loadingMenu = null),
            onOpenForLoading: (Menu item) {
              _loadingMenu = item;
              _controller.pushMenu(item);
              setState(() {});
            },
            setLoadingMenu: (Menu? menu) => setState(() => _loadingMenu = menu),
          ),
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
            onDidRemovePage: (_) {
              _controller.goBack();
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
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _MenuLevelScreen extends StatefulWidget {
  const _MenuLevelScreen({
    required this.menu,
    required this.showBackButton,
    required this.canPopToParent,
    required this.selectedLeafNotifier,
    required this.controller,
    this.onLoadChildren,
    this.loadingMenu,
    this.onLoadingComplete,
    this.onOpenForLoading,
    this.setLoadingMenu,
  });

  final Menu menu;
  final bool showBackButton;
  final bool canPopToParent;
  final ValueNotifier<Menu?> selectedLeafNotifier;
  final StackedMenuController controller;
  final Future<void> Function(Menu menu)? onLoadChildren;
  final Menu? loadingMenu;
  final VoidCallback? onLoadingComplete;
  final void Function(Menu menu)? onOpenForLoading;
  final void Function(Menu? menu)? setLoadingMenu;

  @override
  State<_MenuLevelScreen> createState() => _MenuLevelScreenState();
}

class _MenuLevelScreenState extends State<_MenuLevelScreen> {
  bool _loadStarted = false;

  bool get _isThisPageLoading => widget.loadingMenu?.id == widget.menu.id;

  @override
  void initState() {
    super.initState();
    if (_isThisPageLoading && widget.onLoadChildren != null && !_loadStarted) {
      _loadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runLoad());
    }
  }

  @override
  void didUpdateWidget(_MenuLevelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isThisPageLoading &&
        widget.onLoadChildren != null &&
        !_loadStarted &&
        widget.loadingMenu?.id == widget.menu.id) {
      _loadStarted = true;
      _runLoad();
    }
  }

  Future<void> _runLoad() async {
    if (!mounted || widget.onLoadChildren == null) return;
    try {
      await widget.onLoadChildren!(widget.menu);
    } finally {
      if (!mounted) return;
      _loadStarted = false;
      widget.onLoadingComplete?.call();
      // Rebuild this screen so the list shows newly loaded items (ListenableBuilder may not be in tree during load).
      if (mounted) setState(() {});
      // If still no children after load, treat as leaf: pop this level and show content on the right.
      if (widget.menu.items.isEmpty) {
        widget.controller.goBack();
        widget.controller.selectMenu(widget.menu);
      }
    }
  }

  void _onItemTap(Menu item) {
    final needsLoadThenOpen =
        item.items.isEmpty &&
        item.loadsChildrenDynamically &&
        widget.onLoadChildren != null;
    final refetchOnOpen =
        item.loadChildrenEveryTime &&
        widget.onLoadChildren != null &&
        item.items.isNotEmpty;

    if (needsLoadThenOpen && widget.onOpenForLoading != null) {
      widget.onOpenForLoading!(item);
      return;
    }
    if (refetchOnOpen && widget.setLoadingMenu != null) {
      widget.setLoadingMenu!(item);
      widget.controller.selectMenu(item);
      return;
    }
    widget.controller.selectMenu(item);
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final showPageLoading = _isThisPageLoading;

    final scaffold = Scaffold(
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.controller.goBack,
              )
            : null,
        title: Text(menu.title),
        actions: [
          if (widget.onLoadChildren != null &&
              widget.setLoadingMenu != null &&
              !showPageLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Fetch fresh data',
              onPressed: () => widget.setLoadingMenu!(menu),
            ),
        ],
      ),
      body: showPageLoading
          ? const Center(child: CircularProgressIndicator())
          : (menu.items.isEmpty
                ? const Center(child: Text('No sub-items'))
                : ValueListenableBuilder<Menu?>(
                    valueListenable: widget.selectedLeafNotifier,
                    builder: (context, selectedLeaf, _) {
                      return ListView.builder(
                        itemCount: menu.items.length,
                        itemBuilder: (context, index) {
                          final item = menu.items[index];
                          final showChevron =
                              item.hasChildrenOrLoadsDynamically;
                          final isSelectedLeaf = selectedLeaf?.id == item.id;
                          return ListTile(
                            selected: isSelectedLeaf,
                            selectedTileColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: isSelectedLeaf
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                            trailing: showChevron
                                ? const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  )
                                : null,
                            onTap: () => _onItemTap(item),
                          );
                        },
                      );
                    },
                  )),
    );
    return PopScope(canPop: widget.canPopToParent, child: scaffold);
  }
}
