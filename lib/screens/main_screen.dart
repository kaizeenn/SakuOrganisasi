import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'transaction_list_screen.dart';
import 'event_list_screen.dart';
import 'management_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavItem(
      icon: Icons.grid_view_rounded,
      activeIcon: Icons.grid_view_rounded,
      label: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Transaksi',
    ),
    _NavItem(
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note_rounded,
      label: 'Kegiatan',
    ),
    _NavItem(
      icon: Icons.tune_outlined,
      activeIcon: Icons.tune_rounded,
      label: 'Kelola',
    ),
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    TransactionListScreen(),
    EventListScreen(),
    ManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          8 + MediaQuery.of(context).padding.bottom * 0.4,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final item = _tabs[i];
            final selected = _currentIndex == i;
            return Expanded(
              child: _NavButton(
                item: item,
                selected: selected,
                onTap: () => setState(() => _currentIndex = i),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? p.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                key: ValueKey(selected),
                size: 23,
                color: selected ? p.brand : p.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall?.copyWith(
                color: selected ? p.brand : p.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
