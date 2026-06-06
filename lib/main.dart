import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'pages/splash_page.dart';
import 'services/api_service.dart';
import 'services/localization_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NeoAntApp());
}

class NeoAntApp extends StatefulWidget {
  const NeoAntApp({super.key});

  static _NeoAntAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_NeoAntAppState>();
  }

  @override
  State<NeoAntApp> createState() => _NeoAntAppState();
}

class _NeoAntAppState extends State<NeoAntApp> with WidgetsBindingObserver {
  bool _isDark = false;
  Locale _locale = const Locale('zh');

  void toggleTheme() {
    setState(() => _isDark = !_isDark);
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    LocalizationService().load(locale);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalizationService().load(_locale);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ApiService().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ant Messenger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      home: const SplashPage(),
    );
  }
}
