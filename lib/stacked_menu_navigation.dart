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
  final VoidCallback? _onNavigate;

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
/// is set), or set [loadChildrenEveryTime] true. In your loader, call [Menu.removeItems]
/// before adding new items so the list is replaced, not appended.
class StackedMenuNavigation extends StatefulWidget {
  const StackedMenuNavigation({
    super.key,
    required this.rootMenu,
    this.contentBuilder,
    this.menuWidth = 250,
    this.placeholder,
    this.onLoadChildren,
    this.loadChildrenEveryTime = false,
  });

  /// Root of the menu tree. Can be replaced anytime; controller will use the new root.
  final Menu rootMenu;

  /// Builds the content area when a leaf [Menu] is selected. If null, [placeholder] is used.
  final Widget Function(Menu leaf)? contentBuilder;

  /// Width of the left menu panel.
  final double menuWidth;

  /// Shown in the content area when no leaf is selected. Defaults to a simple container.
  final Widget? placeholder;

  /// Called when the user taps a menu item that has no children (or every time if
  /// [loadChildrenEveryTime] is true). Load data (e.g. from API) and add children via
  /// [menu.addMenu]. Return when done; the item will then open as a branch or leaf.
  final Future<void> Function(Menu menu)? onLoadChildren;

  /// If true, [onLoadChildren] is called every time the user opens that menu (shows
  /// loading each time; useful for refetch). If false (default), it is only called
  /// when the menu has no children yet (cached after first load).
  /// When true, your loader should clear children first (e.g. [Menu.removeItems])
  /// before adding, to avoid duplicates when refetching.
  final bool loadChildrenEveryTime;

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
            onLoadChildren: widget.onLoadChildren,
            loadChildrenEveryTime: widget.loadChildrenEveryTime,
            loadingMenu: _loadingMenu,
            onLoadingComplete: () => setState(() => _loadingMenu = null),
            onOpenForLoading: (Menu item) {
              setState(() => _loadingMenu = item);
              _controller.pushMenu(item);
            },
            setLoadingMenu: (Menu? menu) => setState(() => _loadingMenu = menu),
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
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _MenuLevelScreen extends StatefulWidget {
  const _MenuLevelScreen({
    required this.menu,
    required this.showBackButton,
    required this.selectedLeaf,
    required this.controller,
    this.onLoadChildren,
    this.loadChildrenEveryTime = false,
    this.loadingMenu,
    this.onLoadingComplete,
    this.onOpenForLoading,
    this.setLoadingMenu,
  });

  final Menu menu;
  final bool showBackButton;
  final Menu? selectedLeaf;
  final StackedMenuController controller;
  final Future<void> Function(Menu menu)? onLoadChildren;
  final bool loadChildrenEveryTime;
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
        widget.loadChildrenEveryTime &&
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
    final selectedLeaf = widget.selectedLeaf;
    final showPageLoading = _isThisPageLoading;

    return Scaffold(
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
                : ListView.builder(
                    itemCount: menu.items.length,
                    itemBuilder: (context, index) {
                      final item = menu.items[index];
                      final showChevron = item.hasChildrenOrLoadsDynamically;
                      final isSelectedLeaf = selectedLeaf?.id == item.id;
                      return ListTile(
                        selected: isSelectedLeaf,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: isSelectedLeaf ? FontWeight.w600 : null,
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
                  )),
    );
  }
}
