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
    // Defer notification to avoid setState during didUpdateWidget (causes '!_dirty' assertion).
    final onNavigate = _onNavigate;
    if (onNavigate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onNavigate());
    }
  }

  void _notify() => _onNavigate?.call();

  /// Call after mutating the menu tree (e.g. [Menu.addMenu], [Menu.removeItems])
  /// so the navigation UI rebuilds and shows the updated structure.
  void requestRebuild() {
    _notify();
  }

  /// Deactivates siblings of [menu] and sets [menu] as active.
  void _activateOnly(Menu menu) {
    if (menu.parent != null) {
      for (final s in menu.parent!.items) {
        s.isActive = false;
      }
    }
    menu.isActive = true;
  }

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
    for (final m in path.reversed) {
      _activateOnly(m);
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
      return;
    }
    _activateOnly(menu);
    _notify();
  }

  /// Pushes a menu level (opens the page) even when it has no children yet.
  /// Use before loading children so the transitioned page can show loading.
  void pushMenu(Menu menu) {
    _activateOnly(menu);
    _notify();
  }

  void goBack() {
    final path = getCurrentPath();
    if (path.length <= 1) return;
    path.last.isActive = false;
    final parent = path[path.length - 2];
    _activateOnly(parent);
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
    this.menuBuilder,
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

  /// Builds the left menu panel. If null, a default menu is shown.
  final Widget Function(
    List<Menu> menuItems,
    void Function(Menu item) onTap,
    Menu? selectedLeaf,
  )?
  menuBuilder;

  /// Builds the content area when a leaf [Menu] is selected. If null, [placeholder] is used.
  final Widget Function(Menu leaf)? contentBuilder;

  /// Width of the left menu panel.
  final double menuWidth;

  /// Shown in the content area when no leaf is selected. Defaults to a simple container.
  final Widget? placeholder;

  /// Called when the user taps a menu item that has no children (or every time for
  /// items with [Menu.loadChildrenEveryTime] true). Load data (e.g. from API) and
  /// add children via [menu.addMenu]. Call [requestRebuild] after mutating the menu
  /// so the UI updates; it is also called automatically when this future completes.
  /// Call [Menu.removeItems] before adding when refetching.
  final Future<void> Function(Menu menu, VoidCallback requestRebuild)?
  onLoadChildren;

  @override
  State<StackedMenuNavigation> createState() => _StackedMenuNavigationState();
}

class _StackedMenuNavigationState extends State<StackedMenuNavigation> {
  late StackedMenuController _controller;

  /// Notifier so menu-level screens (inside Navigator routes) can react when loading
  /// starts/ends without relying on receiving a new widget from the parent.
  final ValueNotifier<Menu?> _loadingMenuNotifier = ValueNotifier<Menu?>(null);

  /// Notifier incremented when menu structure changes so menu-level screens rebuild.
  final ValueNotifier<int> _menuStructureVersion = ValueNotifier<int>(0);

  /// When true, the next onDidRemovePage is from our own goBack() (e.g. AppBar back);
  /// we must not call goBack() again in that callback.
  bool _skipNextOnDidRemovePage = false;

  @override
  void initState() {
    super.initState();
    _controller = StackedMenuController(
      root: widget.rootMenu,
      initialSelectedLeaf: widget.initialSelectedLeaf,
      onNavigate: () {
        setState(() {});
        _menuStructureVersion.value++;
      },
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
        await loadChildren(cur, () => _controller.requestRebuild());
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
            menuBuilder: widget.menuBuilder,
            showBackButton: i > 0,
            canPopToParent: isTopPage && path.length > 1,
            selectedLeafNotifier: _controller.selectedLeafNotifier,
            menuStructureVersion: _menuStructureVersion,
            loadingMenuNotifier: _loadingMenuNotifier,
            controller: _controller,
            onBackPressed: () {
              _skipNextOnDidRemovePage = true;
              _controller.goBack();
            },
            onLoadChildren: widget.onLoadChildren,
            onOpenForLoading: (Menu item) {
              _controller.pushMenu(item);
              _loadingMenuNotifier.value = item;
            },
            setLoadingMenu: (Menu? m) => _loadingMenuNotifier.value = m,
          ),
        ),
      );
    }

    final content = selectedLeaf != null
        ? (widget.contentBuilder?.call(selectedLeaf) ??
              _defaultLeafContent(context, selectedLeaf))
        : (widget.placeholder ?? _defaultPlaceholder(context));

    return Row(
      children: [
        SizedBox(
          width: widget.menuWidth,
          child: Navigator(
            pages: pages,
            onDidRemovePage: (_) {
              // Defer so we never call setState during build (Navigator may call this synchronously).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_skipNextOnDidRemovePage) {
                  _skipNextOnDidRemovePage = false;
                  return;
                }
                if (mounted) _controller.goBack();
              });
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
    required this.menuBuilder,
    required this.showBackButton,
    required this.canPopToParent,
    required this.selectedLeafNotifier,
    required this.menuStructureVersion,
    required this.loadingMenuNotifier,
    required this.controller,
    required this.onBackPressed,
    this.onLoadChildren,
    this.onOpenForLoading,
    this.setLoadingMenu,
  });

  final Menu menu;
  final Widget Function(
    List<Menu> menuItems,
    void Function(Menu item) onTap,
    Menu? selectedLeaf,
  )?
  menuBuilder;
  final bool showBackButton;
  final bool canPopToParent;
  final ValueNotifier<Menu?> selectedLeafNotifier;
  final ValueNotifier<int> menuStructureVersion;
  final ValueNotifier<Menu?> loadingMenuNotifier;
  final StackedMenuController controller;
  final VoidCallback onBackPressed;
  final Future<void> Function(Menu menu, VoidCallback requestRebuild)?
  onLoadChildren;
  final void Function(Menu menu)? onOpenForLoading;
  final void Function(Menu? menu)? setLoadingMenu;

  @override
  State<_MenuLevelScreen> createState() => _MenuLevelScreenState();
}

/// Returns the [Menu] that this screen is responsible for loading, if any.
Menu? _menuBeingLoadedFor(Menu screenMenu, Menu? loadingValue) {
  if (loadingValue == null) return null;
  if (loadingValue.id == screenMenu.id) return screenMenu;
  try {
    return screenMenu.items.firstWhere((m) => m.id == loadingValue.id);
  } catch (_) {
    return null;
  }
}

class _MenuLevelScreenState extends State<_MenuLevelScreen> {
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    widget.loadingMenuNotifier.addListener(_onLoadingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLoadingChanged());
  }

  @override
  void dispose() {
    widget.loadingMenuNotifier.removeListener(_onLoadingChanged);
    super.dispose();
  }

  void _onLoadingChanged() {
    if (!mounted) return;
    final menuToLoad = _menuBeingLoadedFor(
      widget.menu,
      widget.loadingMenuNotifier.value,
    );
    if (menuToLoad == null || widget.onLoadChildren == null || _loadStarted)
      return;
    // When we pushed a page for this menu, only that page should run load.
    // When refetching a child (no push), the parent screen runs load.
    final path = widget.controller.getCurrentPath();
    final loadingIsOnStack = path.any((m) => m.id == menuToLoad.id);
    if (menuToLoad.id != widget.menu.id && loadingIsOnStack) return;
    _loadStarted = true;
    _runLoad(menuToLoad);
  }

  VoidCallback get _requestRebuild => widget.controller.requestRebuild;

  Future<void> _runLoad(Menu menuToLoad) async {
    if (!mounted || widget.onLoadChildren == null) return;
    try {
      await widget.onLoadChildren!(menuToLoad, _requestRebuild);
    } finally {
      _loadStarted = false;
      if (mounted) {
        widget.loadingMenuNotifier.value = null;
        widget.controller.requestRebuild();
        if (menuToLoad.id == widget.menu.id && widget.menu.items.isEmpty) {
          widget.onBackPressed();
          widget.controller.selectMenu(widget.menu);
        }
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

    // Open menu level and load (first time or refetch every time).
    if ((needsLoadThenOpen || refetchOnOpen) &&
        widget.onOpenForLoading != null) {
      widget.onOpenForLoading!(item);
      return;
    }
    widget.controller.selectMenu(item);
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    return ValueListenableBuilder<Menu?>(
      valueListenable: widget.loadingMenuNotifier,
      builder: (context, loadingValue, _) {
        final showPageLoading = _menuBeingLoadedFor(menu, loadingValue) != null;
        return PopScope(
          canPop: widget.canPopToParent,
          child: Scaffold(
            appBar: AppBar(
              leading: widget.showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBackPressed,
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
                : ValueListenableBuilder<int>(
                    valueListenable: widget.menuStructureVersion,
                    builder: (context, _, __) {
                      if (menu.items.isEmpty) {
                        return const Center(child: Text('No sub-items'));
                      }
                      return ValueListenableBuilder<Menu?>(
                        valueListenable: widget.selectedLeafNotifier,
                        builder: (context, selectedLeaf, __) {
                          if (widget.menuBuilder != null) {
                            return widget.menuBuilder!(
                              menu.items,
                              _onItemTap,
                              selectedLeaf,
                            );
                          }
                          return ListView.builder(
                            itemCount: menu.items.length,
                            itemBuilder: (context, index) {
                              final item = menu.items[index];
                              final showChevron =
                                  item.hasChildrenOrLoadsDynamically;
                              final isSelectedLeaf =
                                  selectedLeaf?.id == item.id;
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
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
