import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';

/// Entry point khusus untuk WEB ADMIN.
/// Dibuild & di-deploy terpisah dari versi petugas, jadi punya domain sendiri,
/// meski backend/database yang dipakai tetap sama persis.
void main() {
  runApp(const AsetGudangAdminApp());
}

class AsetGudangAdminApp extends StatelessWidget {
  const AsetGudangAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portal Admin - Aset Gudang Komdigi Medan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E5A96),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const _CekSesiAdmin(),
    );
  }
}

class _CekSesiAdmin extends StatelessWidget {
  const _CekSesiAdmin();

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
            : const LoginScreen(expectedRole: 'admin');
      },
    );
  }
}
