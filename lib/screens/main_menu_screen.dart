import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'scan_screen.dart';
import 'home_screen.dart';
import 'peta_screen.dart';
import 'login_screen.dart';
import 'kelola_ruangan_screen.dart';
import 'kelola_akun_screen.dart';
import 'kelola_kategori_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);
  static const Color biruTua = Color(0xFF16213E);

  String? _nama;
  String? _role;

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  Future<void> _muatProfil() async {
    final nama = await AuthService.getNama();
    final role = await AuthService.getRole();
    if (mounted) setState(() {
      _nama = nama;
      _role = role;
    });
  }

  Future<void> _logout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu akan keluar dari akun ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(expectedRole: 'petugas')),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _role == 'admin';
    final jamSekarang = DateTime.now().hour;
    final sapaan = jamSekarang < 11 ? 'Selamat Pagi' : (jamSekarang < 15 ? 'Selamat Siang' : (jamSekarang < 18 ? 'Selamat Sore' : 'Selamat Malam'));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(sapaan, isAdmin),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGambarGedung(),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: const Text(
                      'BBLSDM Komdigi Medan merupakan unit pelaksana teknis yang '
                      'bertugas menyelenggarakan pelatihan di bidang komunikasi, '
                      'informasi, dan digital.',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Menu Utama',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: biruTua)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    children: [
                      _kartuMenu(
                        label: 'Scan QR',
                        ikon: Icons.qr_code_scanner_rounded,
                        warna: tombolCyan,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
                      ),
                      _kartuMenu(
                        label: 'List Barang',
                        ikon: Icons.inventory_2_rounded,
                        warna: const Color(0xFF6C5CE7),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                      ),
                      _kartuMenu(
                        label: 'Peta Lokasi',
                        ikon: Icons.map_rounded,
                        warna: const Color(0xFF2E9E5B),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PetaScreen())),
                      ),
                    ],
                  ),

                  // Menu khusus admin (biasanya admin pakai dashboard sendiri,
                  // tapi disediakan juga di sini kalau suatu saat dibutuhkan)
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    const Text('Kelola Sistem (Admin)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: biruTua)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      children: [
                        _kartuMenu(
                          label: 'Kelola Ruangan',
                          ikon: Icons.meeting_room_rounded,
                          warna: const Color(0xFFCC9A2E),
                          onTap: () =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const KelolaRuanganScreen())),
                        ),
                        _kartuMenu(
                          label: 'Kelola Kategori',
                          ikon: Icons.category_rounded,
                          warna: const Color(0xFFB03A3A),
                          onTap: () =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const KelolaKategoriScreen())),
                        ),
                        _kartuMenu(
                          label: 'Kelola Akun',
                          ikon: Icons.admin_panel_settings_rounded,
                          warna: tombolCyan,
                          onTap: () =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const KelolaAkunScreen())),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String sapaan, bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF29C5E8), Color(0xFF1FA9CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: tombolCyan.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withOpacity(0.25),
              child: Text(
                (_nama != null && _nama!.isNotEmpty) ? _nama![0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sapaan, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(_nama ?? '...',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                          child: const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Keluar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGambarGedung() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        'assets/images/gedung.png',
        width: double.infinity,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: double.infinity,
          height: 150,
          color: Colors.grey.shade300,
          child: const Center(child: Icon(Icons.apartment, size: 48, color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _kartuMenu({
    required String label,
    required IconData ikon,
    required Color warna,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: warna.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(ikon, color: warna, size: 26),
              ),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: biruTua)),
            ],
          ),
        ),
      ),
    );
  }
}
