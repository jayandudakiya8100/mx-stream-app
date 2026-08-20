import 'package:mxstream/functions/themeprovider_class.dart';
import 'package:mxstream/functions/regionprovider_class.dart';

import 'package:mxstream/functions/url_parser.dart';
import 'package:mxstream/functions/navigation_provider.dart';
import 'package:mxstream/widgets/main_shell.dart';
import 'package:mxstream/widgets/check_updates.dart';
import 'package:mxstream/widgets/tv_focus_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';

import 'package:media_kit/media_kit.dart';
import 'package:dynamic_color/dynamic_color.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Only dotenv + Hive are required before first paint; load them in parallel.
  await Future.wait([
    dotenv.load(fileName: ".env"),
    Hive.initFlutter().then((_) => Hive.openBox('sessionBox')),
  ]);

  // Theme/region load asynchronously in their constructors and notify when ready.
  final themeProvider = ThemeProvider(AppThemes.orangeTheme);
  final regionProvider = RegionProvider('worldwide');


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: regionProvider),

        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Defer heavier startup work until after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.wait([
      TvFocusModeManager.init(),
      _initDesktopWindow(),
    ]);
  });
}

Future<void> _initDesktopWindow() async {
  if (kIsWeb ||
      !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }
  await windowManager.ensureInitialized();
  WindowManager.instance.setMinimumSize(const Size(360, 500));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    if (!_isInitialized && (kIsWeb || !Platform.isLinux)) {
      _appLinks = AppLinks();

      // Handle initial URI if the app was launched from a link
      try {
        final uri = await _appLinks.getInitialAppLink();
        final initialUrl =
            uri?.toString() ?? (kIsWeb ? Uri.base.toString() : null);
        if (initialUrl != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (navigatorKey.currentContext != null) {
              await TMDBUrlParser.handleUrl(
                  initialUrl, navigatorKey.currentContext!);
            }
          });
        }
      } catch (e) {
        debugPrint('Error handling initial app link: $e');
      }

      // Handle incoming links while the app is running
      _appLinks.uriLinkStream.listen((uri) async {
        if (navigatorKey.currentContext != null) {
          await TMDBUrlParser.handleUrl(
              uri.toString(), navigatorKey.currentContext!);
        }
      }, onError: (err) {
        debugPrint('Error handling app links: $err');
      });

      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            if (darkDynamic != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                themeProvider.updateSystemDynamicColorScheme(darkDynamic);
              });
            }
            return Listener(
              onPointerDown: (_) => TvFocusModeManager.onPointerDown(),
              child: MaterialApp(
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                title: 'MXStream',
                theme: themeProvider.currentTheme,
                home: const Scaffold(
                  body: AppInitWidget(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AppInitWidget extends StatefulWidget {
  const AppInitWidget({Key? key}) : super(key: key);

  @override
  State<AppInitWidget> createState() => _AppInitWidgetState();
}

class _AppInitWidgetState extends State<AppInitWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        UpdateChecker.checkForUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MainShellPage();
  }
}
