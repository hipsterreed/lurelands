import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/main_menu_screen.dart';
import 'screens/game_screen.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for mobile (landscape only for this game)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Enable immersive fullscreen mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF1A1A2E),
    ),
  );

  runApp(const LurelandsApp());
}

class LurelandsApp extends StatelessWidget {
  const LurelandsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lurelands',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Color(GameColors.pondBlue.toARGB32()),
          secondary: Color(GameColors.grassGreen.toARGB32()),
          surface: Color(GameColors.menuBackground.toARGB32()),
        ),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/game': (context) => const GameScreen(),
      },
    );
  }
}
