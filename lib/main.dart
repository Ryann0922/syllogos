import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  Color _seedColor = Colors.indigo;

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
      if (settings.containsKey('primaryColor')) {
        try {
          _seedColor = Color(settings['primaryColor']);
        } catch (_) {
          _seedColor = Colors.indigo;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _themeStr == 'light'
        ? ThemeMode.light
        : _themeStr == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;

    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );

    ColorScheme darkScheme;
    if (_themeStr == 'amoled') {
      final base = ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      );
      darkScheme = base.copyWith(
        surface: Colors.black,
        surfaceDim: Colors.black,
        surfaceBright: const Color(0xFF1a1a1a),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0d0d0d),
        surfaceContainer: const Color(0xFF141414),
        surfaceContainerHigh: const Color(0xFF1e1e1e),
        surfaceContainerHighest: const Color(0xFF282828),
      );
    } else {
      darkScheme = ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      );
    }
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
  }
}
