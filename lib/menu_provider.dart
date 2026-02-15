import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'menu.dart';

/// Provides the root menu for the app. Replace or override this to supply
/// menu structure dynamically (e.g. from API, config, or different trees).
final menuProvider = Provider<Menu>((ref) {
  final nav = Menu(title: 'nav', isActive: false);
  final products = nav.addMenu('Products');
  _buildProductsMenu(products);
  nav.addMenu('Languages');

  final furniture = products.addMenu('Furniture');
  furniture.addMenu('A2.B1');
  furniture.addMenu('A2.B2');
  furniture.addMenu('A2.B3');
  furniture.addMenu('A2.B4');

  return nav;
});

void _buildProductsMenu(Menu products) {
  final electronics = products.addMenu('Electronics');
  electronics.addMenu('Keyboard');

  // Mouse has no children here; add them dynamically via onLoadChildren.
  electronics.addMenu('Mouse', loadsChildrenDynamically: true);

  final speaker = products.addMenu('Speaker');
  speaker.addMenu('JBL');
  speaker.addMenu('Sony');
  speaker.addMenu('Boat');

  final headphones = products.addMenu('Headphones');
  headphones.addMenu('JBL');
  headphones.addMenu('Sony');
}
