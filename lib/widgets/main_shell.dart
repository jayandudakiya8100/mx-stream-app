import 'package:Mirarr/functions/navigation_provider.dart';
import 'package:Mirarr/moviesPage/mainPage.dart';
import 'package:Mirarr/seriesPage/seriesPage.dart';
import 'package:Mirarr/widgets/bottom_bar.dart';
import 'package:Mirarr/widgets/lazy_indexed_stack.dart';
import 'package:Mirarr/widgets/login.dart';
import 'package:Mirarr/widgets/profile.dart';
import 'package:Mirarr/widgets/search_screen.dart';
import 'package:Mirarr/widgets/shelf_page.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({Key? key}) : super(key: key);

  static const List<Widget> _pages = [
    MovieSearchScreen(),
    SerieSearchScreen(),
    SearchScreen(),
    ShelfPage(),
    AccountTabWrapper(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isTv = TvFocusModeManager.isTvDevice;

    return Scaffold(
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
    );
  }
}

class AccountTabWrapper extends StatelessWidget {
  const AccountTabWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('sessionBox').listenable(),
      builder: (context, Box box, child) {
        final sessionData = box.get('sessionData');
        if (sessionData != null) {
          return ProfilePage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
