import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';

/// Entry point khusus untuk WEB PETUGAS.
/// Dibuild & di-deploy terpisah dari versi admin, jadi punya domain sendiri,
/// meski backend/database yang dipakai tetap sama persis.
void main() {
  runApp(const AsetGudangPetugasApp());
}

class AsetGudangPetugasApp extends StatelessWidget {
  const AsetGudangPetugasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portal Petugas - Aset Gudang Komdigi Medan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF29C5E8),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const _CekSesiPetugas(),
    );
  }
}

class _CekSesiPetugas extends StatelessWidget {
  const _CekSesiPetugas();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final sudahLogin = snapshot.data == true;
        return sudahLogin
            ? const MainNavigationScreen()
            : const LoginScreen(expectedRole: 'petugas');
      },
    );
  }
}
