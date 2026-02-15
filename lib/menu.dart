import 'package:uuid/uuid.dart';

class Menu {
  final String id;
  final String title;
  Menu? parent;
  bool isActive;
  List<Menu> items = [];

  /// When true, children are loaded dynamically (e.g. via onLoadChildren).
  /// Use this so the UI can show a chevron even before children are loaded.
  bool loadsChildrenDynamically;

  Menu({
    required this.title,
    this.isActive = false,
    this.loadsChildrenDynamically = false,
  }) : id = const Uuid().v4() {
    items = [];
  }

  Menu addMenu(String title, {bool loadsChildrenDynamically = false}) {
    final menu = Menu(
      title: title,
      isActive: false,
      loadsChildrenDynamically: loadsChildrenDynamically,
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
    List<Menu>? items,
  }) {
    return Menu(
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      loadsChildrenDynamically:
          loadsChildrenDynamically ?? this.loadsChildrenDynamically,
    )..items = items ?? this.items;
  }
}
