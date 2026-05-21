import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:syllogos/services/storage_service.dart';
import 'package:syllogos/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StorageService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // listen to settings changes in Hive and refresh theme
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
        final t = settings['theme'];
        if (t == 'light') {
          _themeMode = ThemeMode.light;
        } else if (t == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
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
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
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
      themeMode: _themeMode,
      home: const HomePage(),
    );
  }
}
