import 'package:uuid/uuid.dart';

class Menu {
  final String id;
  final String title;
  Menu? parent;
  bool isActive;
  List<Menu> items = [];

  Menu({required this.title, this.isActive = false}) : id = const Uuid().v4() {
    items = [];
  }

  Menu addMenu(String title) {
    final menu = Menu(title: title, isActive: false);
    menu.parent = this;
    items.add(menu);
    return menu;
  }

  void removeItems() {
    items.clear();
  }

  Menu copyWith({
    String? title,
    bool? isActive,
    List<Menu>? items,
  }) {
    return Menu(
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
    )..items = items ?? this.items;
  }
}
