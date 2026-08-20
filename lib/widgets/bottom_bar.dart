import 'package:mxstream/functions/navigation_provider.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:mxstream/utils/expressive_motion.dart';
import 'package:mxstream/widgets/expressive_interactive_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({Key? key}) : super(key: key);

  static double getHeight(BuildContext context) {
    if (TvFocusModeManager.isTvDevice) return 0.0;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    return 60.0 + (bottomPadding > 0 ? bottomPadding : 16.0);
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
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: colorScheme.primary,
          selectedIconTheme: IconThemeData(color: colorScheme.primary),
          unselectedItemColor: colorScheme.onSurfaceVariant,
          currentIndex: navProvider.currentIndex,
          onTap: (int index) {
            navProvider.setIndex(index);
            final modalRoute = ModalRoute.of(context);
            if (modalRoute != null && !modalRoute.isFirst) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search_rounded),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder_rounded),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.file_download_outlined),
              activeIcon: Icon(Icons.download_rounded),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: '',
            ),
          ],
        ),
      );
    }

    final double bottomPadding = MediaQuery.paddingOf(context).bottom;

    final items = const [
      _NavItemData(activeIcon: Icons.home_rounded, inactiveIcon: Icons.home_outlined),
      _NavItemData(activeIcon: Icons.search_rounded, inactiveIcon: Icons.search_outlined),
      _NavItemData(activeIcon: Icons.folder_rounded, inactiveIcon: Icons.folder_outlined),
      _NavItemData(activeIcon: Icons.download_rounded, inactiveIcon: Icons.file_download_outlined),
      _NavItemData(activeIcon: Icons.settings_rounded, inactiveIcon: Icons.settings_outlined),
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
              height: 56,
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
        final modalRoute = ModalRoute.of(context);
        if (modalRoute != null && !modalRoute.isFirst) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      borderRadius: 24,
      pressedBorderRadius: 28,
      speed: ExpressiveSpeed.fast,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Center(
        child: AnimatedContainer(
          duration: ExpressiveSpeed.fast.duration,
          curve: ExpressiveMotion.spatialFast,
          width: isSelected ? 56 : 42,
          height: 36,
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
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavItemData({
    required this.activeIcon,
    required this.inactiveIcon,
  });
}

