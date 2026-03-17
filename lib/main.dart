import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_screen.dart';
import 'screens/auth_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;

  runApp(ProviderScope(child: MyApp(isBiometricEnabled: isBiometricEnabled)));
}

class MyApp extends ConsumerWidget {
  final bool isBiometricEnabled;
  const MyApp({super.key, required this.isBiometricEnabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Apk Bendahara',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id'), // Indonesian
      ],
      home: isBiometricEnabled ? const AuthScreen() : const MainScreen(),
    );
  }
}
