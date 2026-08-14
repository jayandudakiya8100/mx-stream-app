import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _currentTheme;
  SharedPreferences? _prefs;

  bool _isOmarchyLinux = false;
  bool get isOmarchyLinux => _isOmarchyLinux;

  ThemeData? _omarchyTheme;
  ThemeData? get omarchyTheme => _omarchyTheme;

  StreamSubscription<io.FileSystemEvent>? _fileSubscription;

  ColorScheme? _systemDynamicColorScheme;
  ColorScheme? get systemDynamicColorScheme => _systemDynamicColorScheme;

  bool _isDynamicTheme = false;
  bool get isDynamicTheme => _isDynamicTheme;

  ThemeProvider(this._currentTheme) {
    loadTheme();
  }

  ThemeData get currentTheme => _currentTheme;

  void updateSystemDynamicColorScheme(ColorScheme? darkDynamic) {
    if (darkDynamic == null || darkDynamic == _systemDynamicColorScheme) return;
    _systemDynamicColorScheme = darkDynamic;
    if (!_isDynamicTheme) return;
    _currentTheme = AppThemes.buildDynamicTheme(darkDynamic);
    notifyListeners();
  }

  void setTheme(ThemeData theme) async {
    _isDynamicTheme = false;
    _currentTheme = theme;
    notifyListeners();
    await _saveTheme();
  }

  void setDynamicTheme() async {
    _isDynamicTheme = true;
    if (_systemDynamicColorScheme != null) {
      _currentTheme = AppThemes.buildDynamicTheme(_systemDynamicColorScheme!);
    }
    notifyListeners();
    await _saveTheme();
  }

  Future<void> setOmarchyTheme() async {
    _isDynamicTheme = false;
    if (_isOmarchyLinux) {
      final colors = await _loadOmarchyColors();
      _omarchyTheme = _buildOmarchyThemeFromColors(colors);
      setTheme(_omarchyTheme!);
    }
  }

  Future<bool> _checkOmarchyLinux() async {
    if (kIsWeb || !io.Platform.isLinux) return false;
    try {
      final home = io.Platform.environment['HOME'];
      if (home == null) return false;
      return await io.File(
        '$home/.config/omarchy/current/theme/colors.toml',
      ).exists();
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, Color>> _loadOmarchyColors() async {
    final Map<String, Color> colors = {};
    try {
      final home = io.Platform.environment['HOME'];
      if (home == null) return colors;
      final file = io.File('$home/.config/omarchy/current/theme/colors.toml');
      if (!await file.exists()) return colors;

      final lines = await file.readAsLines();
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final eqIndex = line.indexOf('=');
        if (eqIndex == -1) continue;

        final key = line.substring(0, eqIndex).trim();
        var val = line.substring(eqIndex + 1).trim();

        // Strip quotes
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }

        if (val.startsWith('#')) {
          final color = _parseHexColor(val);
          if (color != null) {
            colors[key] = color;
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing Omarchy colors: $e');
    }
    return colors;
  }

  Color? _parseHexColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.startsWith('#')) {
        hexString = hexString.substring(1);
      }
      if (hexString.length == 6) {
        buffer.write('ff');
        buffer.write(hexString);
      } else if (hexString.length == 8) {
        buffer.write(hexString);
      } else {
        return null;
      }
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  ThemeData _buildOmarchyThemeFromColors(Map<String, Color> colors) {
    final accent = colors['accent'] ?? Colors.blueGrey;
    final bg = colors['background'] ?? Colors.black;
    final fg = colors['foreground'] ?? Colors.white;
    final error = colors['color1'] ?? Colors.red;
    final hint = colors['color8'] ?? colors['color7'] ?? Colors.grey[400]!;

    return ThemeData(
      progressIndicatorTheme: const ProgressIndicatorThemeData(),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const FadeForwardsPageTransitionsBuilder(),
        ),
      ),
      fontFamily: 'RobotoMono',
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: accent,
        onPrimary: fg,
        secondary: accent,
        onSecondary: fg,
        error: error,
        onError: fg,
        surface: bg,
        onSurface: fg,
      ),
      highlightColor: accent,
      secondaryHeaderColor: accent,
      hintColor: hint,
      cardColor: accent,
      scaffoldBackgroundColor: bg,
      focusColor: accent.withValues(alpha: 0.3),
      hoverColor: accent.withValues(alpha: 0.15),
      listTileTheme: ListTileThemeData(
        selectedColor: accent,
      ),
    );
  }

  void _startWatchingColorsFile() {
    _fileSubscription?.cancel();
    try {
      final home = io.Platform.environment['HOME'];
      if (home == null) return;
      final dir = io.Directory('$home/.config/omarchy/current/theme');
      if (!dir.existsSync()) return;

      _fileSubscription = dir.watch().listen((event) async {
        if (event.path.endsWith('colors.toml')) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_prefs?.getString('theme') == 'omarchy') {
            await _reloadOmarchyThemeColors();
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting file watch: $e');
    }
  }

  Future<void> _reloadOmarchyThemeColors() async {
    final colors = await _loadOmarchyColors();
    _omarchyTheme = _buildOmarchyThemeFromColors(colors);
    _currentTheme = _omarchyTheme!;
    notifyListeners();
  }

  Future<void> loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    _isOmarchyLinux = await _checkOmarchyLinux();

    if (_isOmarchyLinux) {
      _startWatchingColorsFile();
    }

    String? themeName = _prefs?.getString('theme');
    if (themeName != null) {
      if (themeName == 'dynamic') {
        _isDynamicTheme = true;
        if (_systemDynamicColorScheme != null) {
          _currentTheme = AppThemes.buildDynamicTheme(_systemDynamicColorScheme!);
        }
      } else if (themeName == 'omarchy' && _isOmarchyLinux) {
        final colors = await _loadOmarchyColors();
        _omarchyTheme = _buildOmarchyThemeFromColors(colors);
        _currentTheme = _omarchyTheme!;
      } else {
        switch (themeName) {
          case 'orange':
            _currentTheme = AppThemes.orangeTheme;
            break;
          case 'blue':
            _currentTheme = AppThemes.blueTheme;
            break;
          case 'red':
            _currentTheme = AppThemes.redTheme;
            break;
          case 'brown':
            _currentTheme = AppThemes.brownTheme;
            break;
          case 'grey':
            _currentTheme = AppThemes.greyTheme;
            break;
          case 'yellow':
            _currentTheme = AppThemes.yellowTheme;
            break;
          case 'green':
            _currentTheme = AppThemes.greenTheme;
            break;
          case 'mono':
            _currentTheme = AppThemes.monoFontTheme;
            break;
          case 'nothing':
            _currentTheme = AppThemes.nothingFontTheme;
            break;
          // Add more cases for additional themes
        }
      }
      notifyListeners();
    }
  }

  Future<void> _saveTheme() async {
    String themeName = 'orange'; // Default
    if (_isDynamicTheme) {
      themeName = 'dynamic';
    } else if (_currentTheme == AppThemes.blueTheme) {
      themeName = 'blue';
    } else if (_currentTheme == AppThemes.redTheme) {
      themeName = 'red';
    } else if (_currentTheme == AppThemes.brownTheme) {
      themeName = 'brown';
    } else if (_currentTheme == AppThemes.greyTheme) {
      themeName = 'grey';
    } else if (_currentTheme == AppThemes.yellowTheme) {
      themeName = 'yellow';
    } else if (_currentTheme == AppThemes.greenTheme) {
      themeName = 'green';
    } else if (_currentTheme == AppThemes.monoFontTheme) {
      themeName = 'mono';
    } else if (_currentTheme == AppThemes.nothingFontTheme) {
      themeName = 'nothing';
    } else if (_currentTheme == _omarchyTheme) {
      themeName = 'omarchy';
    }
    await _prefs?.setString('theme', themeName);
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    super.dispose();
  }
}

class AppThemes {
  static ThemeData buildDynamicTheme(
    ColorScheme dynamicColorScheme, {
    String? fontFamily,
  }) {
    final baseColorScheme = dynamicColorScheme.copyWith(
      brightness: Brightness.dark,
      surface: const Color(0xFF0E0E12),
      onSurface: const Color(0xFFE6E1E5),
      surfaceContainerLowest: const Color(0xFF09090C),
      surfaceContainerLow: const Color(0xFF141419),
      surfaceContainer: const Color(0xFF1C1C22),
      surfaceContainerHigh: const Color(0xFF272730),
      surfaceContainerHighest: const Color(0xFF32323E),
    );

    final TextTheme baseTextTheme = ThemeData.dark().textTheme;
    final String resolvedFontFamily = fontFamily ?? 'PlusJakartaSans';
    final TextTheme expressiveTextTheme =
        baseTextTheme.apply(fontFamily: resolvedFontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: const Color(0xFF0E0E12),
      textTheme: expressiveTextTheme,
      fontFamily: resolvedFontFamily,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const ZoomPageTransitionsBuilder(),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: baseColorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: baseColorScheme.surfaceContainerHigh,
        surfaceTintColor: baseColorScheme.surfaceTint,
        modalBackgroundColor: baseColorScheme.surfaceContainerHigh,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        ),
        dragHandleColor: baseColorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: baseColorScheme.surfaceContainerHigh,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: baseColorScheme.surfaceContainerLow,
        selectedColor: baseColorScheme.primaryContainer,
        secondarySelectedColor: baseColorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        brightness: Brightness.dark,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: baseColorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseColorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: baseColorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: baseColorScheme.primary,
            width: 2,
          ),
        ),
        hintStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: baseColorScheme.primaryContainer,
        foregroundColor: baseColorScheme.onPrimaryContainer,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: baseColorScheme.inverseSurface,
        contentTextStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.transparent,
        indicatorColor: baseColorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return expressiveTextTheme.labelMedium?.copyWith(
              color: baseColorScheme.primary,
              fontWeight: FontWeight.bold,
            );
          }
          return expressiveTextTheme.labelMedium?.copyWith(
            color: baseColorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: baseColorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: baseColorScheme.onSurfaceVariant);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: baseColorScheme.primary,
        linearTrackColor: baseColorScheme.surfaceContainerHigh,
        circularTrackColor: baseColorScheme.primary.withValues(alpha: 0.15),
        refreshBackgroundColor: baseColorScheme.surfaceContainerHigh,
      ),
    );
  }

  static ThemeData buildExpressiveTheme({
    required Color seedColor,
    String? fontFamily,
    Brightness brightness = Brightness.dark,
  }) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: const Color(0xFF0E0E12),
      onSurface: const Color(0xFFE6E1E5),
      surfaceContainerLowest: const Color(0xFF09090C),
      surfaceContainerLow: const Color(0xFF141419),
      surfaceContainer: const Color(0xFF1C1C22),
      surfaceContainerHigh: const Color(0xFF272730),
      surfaceContainerHighest: const Color(0xFF32323E),
    );

    final TextTheme baseTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final String resolvedFontFamily = fontFamily ?? 'PlusJakartaSans';
    final TextTheme expressiveTextTheme =
        baseTextTheme.apply(fontFamily: resolvedFontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: const Color(0xFF0E0E12),
      textTheme: expressiveTextTheme,
      fontFamily: resolvedFontFamily,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const ZoomPageTransitionsBuilder(),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: baseColorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: baseColorScheme.surfaceContainerHigh,
        surfaceTintColor: baseColorScheme.surfaceTint,
        modalBackgroundColor: baseColorScheme.surfaceContainerHigh,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        ),
        dragHandleColor: baseColorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: baseColorScheme.surfaceContainerHigh,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: baseColorScheme.surfaceContainerLow,
        selectedColor: baseColorScheme.primaryContainer,
        secondarySelectedColor: baseColorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        brightness: brightness,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: baseColorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseColorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: baseColorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: baseColorScheme.primary,
            width: 2,
          ),
        ),
        hintStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: baseColorScheme.primaryContainer,
        foregroundColor: baseColorScheme.onPrimaryContainer,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: baseColorScheme.inverseSurface,
        contentTextStyle: expressiveTextTheme.bodyMedium?.copyWith(
          color: baseColorScheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.transparent,
        indicatorColor: baseColorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return expressiveTextTheme.labelMedium?.copyWith(
              color: baseColorScheme.primary,
              fontWeight: FontWeight.bold,
            );
          }
          return expressiveTextTheme.labelMedium?.copyWith(
            color: baseColorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: baseColorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: baseColorScheme.onSurfaceVariant);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: baseColorScheme.primary,
        linearTrackColor: baseColorScheme.surfaceContainerHigh,
        circularTrackColor: baseColorScheme.primary.withValues(alpha: 0.15),
        refreshBackgroundColor: baseColorScheme.surfaceContainerHigh,
      ),
    );
  }

  static final ThemeData orangeTheme = buildExpressiveTheme(
    seedColor: const Color(0xFFFF9800),
  );

  static final ThemeData blueTheme = buildExpressiveTheme(
    seedColor: const Color(0xFF2196F3),
  );

  static final ThemeData redTheme = buildExpressiveTheme(
    seedColor: const Color(0xFFF44336),
  );

  static final ThemeData greyTheme = buildExpressiveTheme(
    seedColor: const Color(0xFF9E9E9E),
  );

  static final ThemeData yellowTheme = buildExpressiveTheme(
    seedColor: const Color(0xFFFFEB3B),
  );

  static final ThemeData brownTheme = buildExpressiveTheme(
    seedColor: const Color(0xFF795548),
  );

  static final ThemeData greenTheme = buildExpressiveTheme(
    seedColor: const Color(0xFF4CAF50),
  );

  static final ThemeData monoFontTheme = buildExpressiveTheme(
    seedColor: const Color(0xFF607D8B),
    fontFamily: 'RobotoMono',
  );

  static final ThemeData nothingFontTheme = buildExpressiveTheme(
    seedColor: const Color(0xFFD32F2F),
    fontFamily: 'Nothing',
  );
}

