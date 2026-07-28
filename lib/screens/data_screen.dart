import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/refrescable.dart';
import '../models/titik_lokasi.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> implements Refrescable {
  static const Color tombolCyan = Color(0xFF29C5E8);

  bool _loading = true;
  List<Map<String, dynamic>> _semuaUser = []; // admin & petugas
  Map<String, TitikLokasi> _terakhirDipinjam = {};
  Map<String, TitikLokasi> _terakhirDikembalikan = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  Future<void> refreshDiam() => _muat(tampilkanLoading: false);

  Future<void> _muat({bool tampilkanLoading = true}) async {
    if (tampilkanLoading) setState(() => _loading = true);
    try {
      final hasil = await Future.wait([
        ApiService.getUsers(), // semua akun, admin & petugas
        ApiService.getRiwayat(), // sudah terurut terbaru duluan
      ]);
      final users = hasil[0] as List<Map<String, dynamic>>;
      final riwayat = hasil[1] as List<TitikLokasi>;

      final Map<String, TitikLokasi> dipinjam = {};
      final Map<String, TitikLokasi> dikembalikan = {};

      for (final r in riwayat) {
        final nama = r.namaPetugas;
        if (nama == null) continue;
        if (r.isPeminjaman && !dipinjam.containsKey(nama)) {
          dipinjam[nama] = r;
        } else if (r.isPengembalian && !dikembalikan.containsKey(nama)) {
          dikembalikan[nama] = r;
        }
      }

      if (mounted) {
        setState(() {
          _semuaUser = users;
          _terakhirDipinjam = dipinjam;
          _terakhirDikembalikan = dikembalikan;
        });
      }
    } catch (e) {
      if (mounted && tampilkanLoading) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat: $e')));
      }
    } finally {
      if (mounted && tampilkanLoading) setState(() => _loading = false);
    }
  }

  String _formatWaktu(DateTime dt) {
    final w = dt.toLocal();
    return '${w.day}/${w.month}/${w.year} ${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _muat,
                    child: _semuaUser.isEmpty
                        ? ListView(
                            children: const [SizedBox(height: 100), Center(child: Text('Belum ada akun.'))],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _semuaUser.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final u = _semuaUser[index];
                              final isAdmin = u['role'] == 'admin';
                              final pinjam = _terakhirDipinjam[u['name']];
                              final kembali = _terakhirDikembalikan[u['name']];
                              return Container(
                          padding: const EdgeInsets.all(14),
                          decoration:
                              BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: isAdmin ? tombolCyan : tombolCyan.withOpacity(0.2),
                                child: Text(u['name'].toString().substring(0, 1).toUpperCase(),
                                    style: TextStyle(color: isAdmin ? Colors.white : Colors.black87)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                                color: tombolCyan.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8)),
                                            child: const Text('ADMIN',
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(u['email'],
                                        style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                    const SizedBox(height: 8),
                                    if (pinjam != null)
                                      Text(
                                        'Terakhir dipinjam: ${pinjam.namaBarang}'
                                        '${pinjam.namaPeminjam != null && pinjam.namaPeminjam!.isNotEmpty ? " (untuk ${pinjam.namaPeminjam})" : ""}'
                                        ' — ${_formatWaktu(pinjam.scannedAt)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      )
                                    else
                                      const Text('Belum pernah meminjam',
                                          style: TextStyle(fontSize: 12, color: Colors.black38)),
                                    if (kembali != null)
                                      Text(
                                        'Terakhir dikembalikan: ${kembali.namaBarang} — ${_formatWaktu(kembali.scannedAt)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF29C5E8), Color(0xFF1FA9CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: tombolCyan.withOpacity(0.2), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Kembali',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Dashboard Data (${_semuaUser.length} Pengguna)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          IconButton(
            onPressed: _muat,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
    );
  }
}
