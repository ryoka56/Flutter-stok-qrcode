import 'package:flutter/material.dart';
import 'tinjauan_screen.dart';
import 'data_screen.dart';
import 'informasi_screen.dart';
import 'pengaturan_screen.dart';
import 'main_menu_screen.dart';
import 'riwayat_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/refrescable.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);
  static const double _breakpointDesktop = 700;

  int _tabTerpilih = 0;
  bool _isAdmin = false;
  bool _loading = true;
  String _namaAkun = '';

  // Tiap halaman punya GlobalKey sendiri supaya, waktu menu diklik, kita
  // bisa manggil refreshDiam() langsung ke State-nya (kalau dia
  // implementasikan Refrescable) TANPA bikin ulang widget-nya dari nol.
  // Ini bedanya sama pendekatan lama yang selalu nge-blank + loading penuh
  // tiap ganti menu — sekarang data lama tetap kelihatan sambil data baru
  // diambil diam-diam di belakang layar, jadi kerasa jauh lebih cepat.
  final List<GlobalKey<State>> _pageKeys = List.generate(5, (_) => GlobalKey<State>());

  void _pilihTab(int index) {
    setState(() => _tabTerpilih = index);
    // Kasih sedikit jeda supaya widget yang baru pertama kali dibuat
    // (kalau ini kunjungan pertama ke tab itu) sempat ke-mount dulu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _pageKeys[index].currentState;
      if (state is Refrescable) {
        (state as Refrescable).refreshDiam();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _cekRole();
  }

  Future<void> _cekRole() async {
    final admin = await AuthService.isAdmin();
    final nama = await AuthService.getNama();
    if (mounted) {
      setState(() {
        _isAdmin = admin;
        _namaAkun = (nama != null && nama.isNotEmpty) ? nama : 'Pengguna';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: Text('Kamu akan keluar dari akun "$_namaAkun".'),
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

    final peranSebelumnya = _isAdmin ? 'admin' : 'petugas';
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(expectedRole: peranSebelumnya)),
      (route) => false,
    );
  }

  // Admin: Tinjauan, Data, Riwayat, Informasi, Pengaturan (sesuai desain dashboard)
  // Petugas: Home, Riwayat (navigasi sederhana)
  List<Widget> get _halaman => _isAdmin
      ? [
          TinjauanScreen(key: _pageKeys[0]),
          DataScreen(key: _pageKeys[1]),
          RiwayatScreen(key: _pageKeys[2]),
          InformasiScreen(key: _pageKeys[3]),
          PengaturanScreen(key: _pageKeys[4]),
        ]
      : [
          MainMenuScreen(key: _pageKeys[0]),
          RiwayatScreen(key: _pageKeys[1]),
        ];

  List<_MenuNav> get _daftarMenu => _isAdmin
      ? const [
          _MenuNav(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Tinjauan'),
          _MenuNav(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Data'),
          _MenuNav(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Riwayat'),
          _MenuNav(icon: Icons.info_outline, activeIcon: Icons.info, label: 'Informasi'),
          _MenuNav(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Pengaturan'),
        ]
      : const [
          _MenuNav(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
          _MenuNav(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Riwayat'),
        ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabAman = _tabTerpilih < _halaman.length ? _tabTerpilih : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _breakpointDesktop;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFFF3F5F9),
            body: Row(
              children: [
                _buildSidebarKiri(tabAman),
                Expanded(child: IndexedStack(index: tabAman, children: _halaman)),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F5F9),
          body: IndexedStack(index: tabAman, children: _halaman),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            clipBehavior: Clip.antiAlias,
            child: BottomNavigationBar(
              currentIndex: tabAman,
              onTap: _pilihTab,
              selectedItemColor: tombolCyan,
              unselectedItemColor: Colors.black38,
              backgroundColor: Colors.white,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              items: _daftarMenu
                  .map((m) => BottomNavigationBarItem(icon: Icon(m.icon), activeIcon: Icon(m.activeIcon), label: m.label))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarKiri(int tabAman) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(3, 0))],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: tombolCyan, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.apartment, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('BBLSDM\nKomdigi Medan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.25)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < _daftarMenu.length; i++) _buildItemSidebar(i, tabAman == i),
            const Spacer(),
            _buildAkunSidebar(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAkunSidebar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF3F5F9), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: tombolCyan.withOpacity(0.18),
                child: Text(
                  _namaAkun.isNotEmpty ? _namaAkun[0].toUpperCase() : '?',
                  style: const TextStyle(color: tombolCyan, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_namaAkun,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(_isAdmin ? 'Admin' : 'Petugas',
                        style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
              const Icon(Icons.logout_rounded, size: 16, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemSidebar(int index, bool terpilih) {
    final menu = _daftarMenu[index];
    return InkWell(
      onTap: () => _pilihTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: terpilih ? tombolCyan.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: terpilih ? tombolCyan : Colors.transparent, width: 3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Icon(terpilih ? menu.activeIcon : menu.icon, color: terpilih ? tombolCyan : Colors.black45, size: 21),
            const SizedBox(width: 12),
            Text(menu.label,
                style: TextStyle(
                    fontSize: 13.5,
                    color: terpilih ? tombolCyan : Colors.black87,
                    fontWeight: terpilih ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _MenuNav {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _MenuNav({required this.icon, required this.activeIcon, required this.label});
}
