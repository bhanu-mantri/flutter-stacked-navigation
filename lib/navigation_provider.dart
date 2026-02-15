import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'menu.dart';

class NavigationState {
  const NavigationState({required this.root, this.selectedLeaf});
  final Menu root;
  final Menu? selectedLeaf;
  NavigationState copyWith({Menu? root, Menu? selectedLeaf}) => NavigationState(
    root: root ?? this.root,
    selectedLeaf: selectedLeaf ?? this.selectedLeaf,
  );
}

class NavigationNotifier extends Notifier<NavigationState> {
  @override
  build() {
    final nav = Menu(title: 'nav', isActive: false);
    final products = nav.addMenu('Products');
    _buildProductsMenu(products);
    nav.addMenu('Languages');

    final furniture = products.addMenu('Furniture');
    furniture.addMenu('A2.B1');
    furniture.addMenu('A2.B2');
    furniture.addMenu('A2.B3');
    furniture.addMenu('A2.B4');

    return NavigationState(root: nav, selectedLeaf: null);
  }

  void _buildProductsMenu(Menu products) {
    final electronics = products.addMenu('Electronics');
    electronics.addMenu('Keyboard');

    final mouse = electronics.addMenu('Mouse');
    mouse.addMenu('Acer');
    mouse.addMenu('Dell');

    final speaker = electronics.addMenu('Speaker');
    speaker.addMenu('JBL');
    speaker.addMenu('Sony');
    speaker.addMenu('Boat');

    final headphones = electronics.addMenu('Headphones');
    headphones.addMenu('JBL');
    headphones.addMenu('Sony');
  }

  /// Returns the path from root to the current (deepest active) menu. Does not include leaf selection.
  List<Menu> getCurrentPath() {
    final path = <Menu>[state.root];
    Menu cur = state.root;
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
      // Leaf: only set selected leaf, do not push a menu level
      state = NavigationState(root: state.root, selectedLeaf: menu);
      return;
    }
    for (var item in menu.parent!.items) {
      item.isActive = false;
    }
    menu.isActive = true;
    Menu? root = menu;
    while (root?.parent != null) {
      root = root?.parent;
    }
    state = NavigationState(root: root!, selectedLeaf: state.selectedLeaf);
  }

  /// Pops the current level and selects the parent menu (slide-back).
  /// Keeps the selected leaf so its content stays visible until user selects something else.
  void goBack() {
    final path = getCurrentPath();
    if (path.length <= 1) return;
    path.last.isActive = false;
    final parent = path[path.length - 2];
    if (parent.parent != null) {
      for (var item in parent.parent!.items) {
        item.isActive = false;
      }
      parent.isActive = true;
    }
    state = NavigationState(root: state.root, selectedLeaf: state.selectedLeaf);
  }
}

final navigationProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
      NavigationNotifier.new,
    );
