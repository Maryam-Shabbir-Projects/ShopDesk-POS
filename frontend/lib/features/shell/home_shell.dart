import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = <_Destination>[
  _Destination('/home', 'Home', Icons.dashboard_outlined, Icons.dashboard),
  _Destination('/sell', 'Sell', Icons.point_of_sale_outlined, Icons.point_of_sale),
  _Destination('/stock', 'Stock', Icons.inventory_2_outlined, Icons.inventory_2),
  _Destination('/sales', 'Sales', Icons.receipt_long_outlined, Icons.receipt_long),
  _Destination('/predict', 'Predict', Icons.insights_outlined, Icons.insights),
];

/// Bottom bar on phones, side rail on tablets and desktop.
/// Every tab is open to everyone until sign-in is added back.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = _destinations;
    final index = items.indexWhere((d) => location.startsWith(d.path)).clamp(0, items.length - 1).toInt();
    void select(int i) => context.go(items[i].path);
    final wide = MediaQuery.sizeOf(context).width >= 800;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in items)
                  NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: [
          for (final d in items)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
