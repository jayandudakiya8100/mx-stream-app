import 'package:mxstream/functions/navigation_provider.dart';
import 'package:mxstream/homePage/homePage.dart';
import 'package:mxstream/widgets/bottom_bar.dart';
import 'package:mxstream/widgets/downloads_page.dart';
import 'package:mxstream/widgets/lazy_indexed_stack.dart';
import 'package:mxstream/widgets/search_screen.dart';
import 'package:mxstream/widgets/settings_screen.dart';
import 'package:mxstream/widgets/shelf_page.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({Key? key}) : super(key: key);

  static const List<Widget> _pages = [
    HomeScreen(),
    SearchScreen(),
    ShelfPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isTv = TvFocusModeManager.isTvDevice;
    final navProvider = Provider.of<NavigationProvider>(context);

    return PopScope(
      canPop: navProvider.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navProvider.currentIndex != 0) {
          navProvider.setIndex(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Column(
          children: [
            if (isTv) const BottomBar(),
            Expanded(
              // Build tabs on first visit so cold start only fetches the active page.
              child: Selector<NavigationProvider, int>(
                selector: (_, nav) => nav.currentIndex,
                builder: (context, index, _) {
                  return LazyIndexedStack(
                    index: index,
                    children: _pages,
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: isTv ? null : const BottomBar(),
      ),
    );
  }
}
