/// Simple menu model (plain state, no listeners).
class Menu {
  static int _nextId = 0;

  final String id;
  final String title;
  Menu? parent;
  bool isActive;
  List<Menu> items = [];

  /// When true, children are loaded dynamically (e.g. via onLoadChildren).
  /// Use this so the UI can show a chevron even before children are loaded.
  bool loadsChildrenDynamically;

  /// When true, children are refetched every time this menu is opened (e.g. live data).
  /// Only applies when [loadsChildrenDynamically] is true or children were loaded dynamically.
  bool loadChildrenEveryTime;

  Menu({
    required this.title,
    this.isActive = false,
    this.loadsChildrenDynamically = false,
    this.loadChildrenEveryTime = false,
  }) : id = 'menu_${_nextId++}',
       items = [];

  Menu addMenu(
    dynamic title, {
    bool loadsChildrenDynamically = false,
    bool loadChildrenEveryTime = false,
  }) {
    final menu = Menu(
      title: title,
      isActive: false,
      loadsChildrenDynamically: loadsChildrenDynamically,
      loadChildrenEveryTime: loadChildrenEveryTime,
    );
    menu.parent = this;
    items.add(menu);
    return menu;
  }

  /// True if this item has children now or will have them loaded dynamically.
  bool get hasChildrenOrLoadsDynamically =>
      items.isNotEmpty || loadsChildrenDynamically;

  void removeItems() {
    items.clear();
  }

  Menu copyWith({
    String? title,
    bool? isActive,
    bool? loadsChildrenDynamically,
    bool? loadChildrenEveryTime,
    List<Menu>? items,
  }) {
    return Menu(
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      loadsChildrenDynamically:
          loadsChildrenDynamically ?? this.loadsChildrenDynamically,
      loadChildrenEveryTime:
          loadChildrenEveryTime ?? this.loadChildrenEveryTime,
    )..items = items ?? this.items;
  }
}
