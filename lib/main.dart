import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const AsetGudangApp());
}

class AsetGudangApp extends StatelessWidget {
  const AsetGudangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aset Gudang Komdigi Medan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3A8FC0),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
