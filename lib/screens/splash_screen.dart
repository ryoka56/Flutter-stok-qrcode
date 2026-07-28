import 'package:flutter/material.dart';
import '../widgets/corner_decoration.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const Color backgroundColor = Color(0xFFB9CBDD);
  static const Color tombolCyan = Color(0xFF29C5E8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            const CornerDecoration(topLeft: true),
            const CornerDecoration(topLeft: false),
            const Positioned(
              right: 90,
              bottom: 140,
              child: SmallSquareAccent(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 3),
                  Center(child: _buildLogo()),
                  const Spacer(flex: 3),
                  const Text(
                    'Kelola Barang yang\nkamu butuhkan',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'kamu bisa meminjam dan memakai barang sesuai\ndengan keperluan',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTombolMasuk(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _buildLogoFallback(),
      ),
    );
  }

  Widget _buildLogoFallback() {
    // Dipakai kalau file assets/images/logo.png belum tersedia,
    // supaya app tetap bisa jalan tanpa crash.
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFF1E5A96), width: 6),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                children: [
                  TextSpan(text: 'BB', style: TextStyle(color: Color(0xFF1E5A96))),
                  TextSpan(text: 'L', style: TextStyle(color: Color(0xFF3A8FC0))),
                  TextSpan(text: 'SDM', style: TextStyle(color: Color(0xFF1E5A96))),
                ],
              ),
            ),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1),
                children: [
                  TextSpan(text: 'KOM', style: TextStyle(color: Color(0xFF1E5A96))),
                  TextSpan(text: 'D', style: TextStyle(color: Color(0xFFB03A3A))),
                  TextSpan(text: 'IGI', style: TextStyle(color: Color(0xFF1E5A96))),
                ],
              ),
            ),
            const Text(
              'M E D A N',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: Color(0xFF3A8FC0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTombolMasuk(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final sudahLogin = await AuthService.isLoggedIn();
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => sudahLogin ? const MainNavigationScreen() : const LoginScreen(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: tombolCyan,
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        elevation: 0,
      ),
      child: const Text(
        'Masuk',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
