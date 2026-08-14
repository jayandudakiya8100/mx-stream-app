import 'package:Mirarr/functions/navigation_provider.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:Mirarr/utils/expressive_motion.dart';
import 'package:Mirarr/widgets/expressive_interactive_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({Key? key}) : super(key: key);

  static double getHeight(BuildContext context) {
    if (TvFocusModeManager.isTvDevice) return 0.0;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    return 72.0 + (bottomPadding > 0 ? bottomPadding : 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    final bool isTv = TvFocusModeManager.isTvDevice;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isTv) {
      return Focus(
        focusNode: TvFocusModeManager.bottomBarFocusNode,
        canRequestFocus: false,
        child: BottomNavigationBar(
          selectedItemColor: colorScheme.primary,
          selectedIconTheme: IconThemeData(color: colorScheme.primary),
          selectedFontSize: 16,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          currentIndex: navProvider.currentIndex,
          onTap: (int index) {
            navProvider.setIndex(index);
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.movie_outlined),
              activeIcon: Icon(Icons.movie),
              label: 'Movies',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tv_outlined),
              activeIcon: Icon(Icons.tv),
              label: 'Series',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_library_outlined),
              activeIcon: Icon(Icons.video_library),
              label: 'Shelf',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      );
    }

    final double bottomPadding = MediaQuery.paddingOf(context).bottom;

    final items = const [
      _NavItemData(activeIcon: Icons.movie, inactiveIcon: Icons.movie_outlined, label: 'Movies'),
      _NavItemData(activeIcon: Icons.tv, inactiveIcon: Icons.tv_outlined, label: 'Series'),
      _NavItemData(activeIcon: Icons.search, inactiveIcon: Icons.search_outlined, label: 'Search'),
      _NavItemData(activeIcon: Icons.video_library, inactiveIcon: Icons.video_library_outlined, label: 'Shelf'),
      _NavItemData(activeIcon: Icons.person, inactiveIcon: Icons.person_outline, label: 'Account'),
    ];

    return Center(
      heightFactor: 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, bottomPadding > 0 ? bottomPadding : 16.0),
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(36.0),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 66,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(items.length, (index) {
                    return _buildM3ExpressiveItem(
                      context,
                      navProvider,
                      index,
                      items[index],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildM3ExpressiveItem(
    BuildContext context,
    NavigationProvider navProvider,
    int index,
    _NavItemData itemData,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isSelected = navProvider.currentIndex == index;

    return ExpressiveInteractiveContainer(
      onTap: () {
        navProvider.setIndex(index);
        Navigator.popUntil(context, (route) => route.isFirst);
      },
      borderRadius: 24,
      pressedBorderRadius: 28,
      speed: ExpressiveSpeed.fast,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: ExpressiveSpeed.fast.duration,
            curve: ExpressiveMotion.spatialFast,
            width: isSelected ? 52 : 38,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: ExpressiveSpeed.fast.duration,
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isSelected ? itemData.activeIcon : itemData.inactiveIcon,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: ExpressiveSpeed.fast.duration,
            style: TextStyle(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
            child: Text(itemData.label),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavItemData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

