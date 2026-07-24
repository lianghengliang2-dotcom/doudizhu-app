import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'providers/game_provider.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/new_session_screen.dart';
import 'screens/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DoudizhuApp());
}

class DoudizhuApp extends StatelessWidget {
  const DoudizhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider(db)..loadPlayers()),
        ChangeNotifierProvider(create: (_) => GameProvider(db)..loadLatestSession()),
      ],
      child: MaterialApp(
        title: '斗地主记分',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          colorSchemeSeed: const Color(0xFFC41E1E),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0A0A0A),
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFFF5E6C8),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(color: Color(0xFFF5E6C8)),
          ),
          cardTheme: const CardTheme(
            color: Color(0xFF1C1410),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              side: BorderSide(color: Color(0xFF8B6914), width: 1),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFF1C1410),
            labelStyle: const TextStyle(color: Color(0xFFF5E6C8), fontSize: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: const BorderSide(color: Color(0xFF8B6914)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC41E1E),
              foregroundColor: const Color(0xFFF5E6C8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF5E6C8),
              side: const BorderSide(color: Color(0xFF8B6914)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return const Color(0xFFC4952A);
              return const Color(0xFF8B7355);
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return const Color(0xFFC4952A).withOpacity(0.3);
              return const Color(0xFF1C1410);
            }),
          ),
          dividerTheme: const DividerThemeData(color: Color(0xFF8B6914)),
          inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: Color(0xFF8B7355)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B6914))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC4952A))),
          ),
        ),
        home: const HomeScreen(),
        routes: {
          '/settings': (_) => const SettingsScreen(),
          '/new-session': (_) => const NewSessionScreen(),
          '/history': (_) => const HistoryScreen(),
        },
      ),
    );
  }
}
