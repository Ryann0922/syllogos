import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:syllogos/services/storage_service.dart';
import 'package:syllogos/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StorageService.init();
  runApp(MyApp(key: MyApp.appKey));
}

class MyApp extends StatefulWidget {
  static final GlobalKey<_MyAppState> appKey = GlobalKey<_MyAppState>();
  MyApp({super.key});

  static void refreshTheme() {
    appKey.currentState?._loadSettings();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _themeStr = 'system';
  Color? _seedColor; // null = use system dynamic color
  bool get _useDynamicColor => _seedColor == null;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    try {
      Hive.box('settings').listenable().addListener(() {
        _loadSettings();
      });
    } catch (e) {
      // box may not be ready for listenable; ignore
    }
  }

  void _loadSettings() {
    final settings = StorageService.getSettings();
    setState(() {
      if (settings.containsKey('theme')) {
        _themeStr = settings['theme'];
      }
      if (settings.containsKey('primaryColor') &&
          settings['primaryColor'] != null) {
        try {
          _seedColor = Color(settings['primaryColor']);
        } catch (_) {
          _seedColor = null;
        }
      } else {
        _seedColor = null;
      }
    });
  }

  ColorScheme _makeLightScheme(Color? dynamicPrimary) {
    if (_useDynamicColor && dynamicPrimary != null) {
      // Dynamic mode: use wallpaper primary as seed → good surface contrast
      return ColorScheme.fromSeed(
        seedColor: dynamicPrimary,
        brightness: Brightness.light,
      );
    }
    // Preset or fallback
    return ColorScheme.fromSeed(
      seedColor: _seedColor ?? Colors.indigo,
      brightness: Brightness.light,
    );
  }

  ColorScheme _makeDarkScheme(Color? dynamicPrimary) {
    if (_themeStr == 'amoled') {
      final base = (_useDynamicColor && dynamicPrimary != null)
          ? ColorScheme.fromSeed(
              seedColor: dynamicPrimary,
              brightness: Brightness.dark,
            )
          : ColorScheme.fromSeed(
              seedColor: _seedColor ?? Colors.indigo,
              brightness: Brightness.dark,
            );
      return base.copyWith(
        surface: Colors.black,
        surfaceDim: Colors.black,
        surfaceBright: const Color(0xFF1a1a1a),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0d0d0d),
        surfaceContainer: const Color(0xFF141414),
        surfaceContainerHigh: const Color(0xFF1e1e1e),
        surfaceContainerHighest: const Color(0xFF282828),
      );
    }
    if (_useDynamicColor && dynamicPrimary != null) {
      return ColorScheme.fromSeed(
        seedColor: dynamicPrimary,
        brightness: Brightness.dark,
      );
    }
    return ColorScheme.fromSeed(
      seedColor: _seedColor ?? Colors.indigo,
      brightness: Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _themeStr == 'light'
        ? ThemeMode.light
        : _themeStr == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = _makeLightScheme(lightDynamic?.primary);
        final darkScheme = _makeDarkScheme(darkDynamic?.primary);

        final theme = ThemeData(
          colorScheme: lightScheme,
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );

        final dark = ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Syllogos',
          theme: theme,
          darkTheme: dark,
          themeMode: themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
