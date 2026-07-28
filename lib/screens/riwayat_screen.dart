import 'package:flutter/material.dart';
import '../models/titik_lokasi.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/refrescable.dart';

class RiwayatScreen extends StatefulWidget {
  /// Kalau true, cuma nampilin riwayat yang terjadi HARI INI (dipakai waktu
  /// dibuka dari kartu "Kegiatan hari ini" di Dashboard Tinjauan).
  final bool hanyaHariIni;

  /// Kalau diisi, riwayat difilter cuma punya barang ini saja (dipakai
  /// waktu dibuka dari Kelola Barang lewat tombol "Lihat riwayat lokasi",
  /// supaya histori lokasi sebelumnya - bukan cuma yang terakhir - bisa
  /// dilihat lengkap, sinkron dengan data yang sama persis dengan tab Riwayat).
  final int? assetId;
  final String? judulFilter;

  const RiwayatScreen({super.key, this.hanyaHariIni = false, this.assetId, this.judulFilter});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> implements Refrescable {
  static const Color tombolCyan = Color(0xFF29C5E8);
  static const Color biruTua = Color(0xFF16213E);

  late Future<List<TitikLokasi>> _futureRiwayat;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _daftarPetugas = [];
  int? _filterUserId;

  @override
  void initState() {
    super.initState();
    _futureRiwayat = ApiService.getRiwayat(assetId: widget.assetId, hariIni: widget.hanyaHariIni);
    _cekRoleDanMuatFilter();
  }

  @override
  Future<void> refreshDiam() async {
    // Sama kayak InformasiScreen: ambil dulu di background, baru pasang
    // ke _futureRiwayat kalau udah selesai, biar gak sempat nunjukin
    // spinner FutureBuilder di tengah list yang udah ada isinya.
    try {
      final data = await ApiService.getRiwayat(assetId: widget.assetId, userId: _filterUserId, hariIni: widget.hanyaHariIni);
      if (mounted) setState(() => _futureRiwayat = Future.value(data));
    } catch (_) {
      // gagal diam-diam, data lama tetap tampil
    }
  }

  Future<void> _cekRoleDanMuatFilter() async {
    final admin = await AuthService.isAdmin();
    if (!mounted) return;
    setState(() => _isAdmin = admin);

    if (admin) {
      try {
        final users = await ApiService.getUsers();
        if (mounted) {
          setState(() => _daftarPetugas = users.where((u) => u['role'] == 'petugas').toList());
        }
      } catch (_) {
        // biarkan filter kosong kalau gagal ambil daftar petugas
      }
    }
  }

  void _muatUlang() {
    setState(() {
      _futureRiwayat = ApiService.getRiwayat(assetId: widget.assetId, userId: _filterUserId, hariIni: widget.hanyaHariIni);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Column(
        children: [
          _buildHeader(),
          // Filter per petugas - cuma muncul untuk admin
          if (_isAdmin && _daftarPetugas.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: DropdownButtonFormField<int?>(
                value: _filterUserId,
                decoration: InputDecoration(
                  labelText: 'Filter berdasarkan petugas',
                  filled: true,
                  fillColor: const Color(0xFFF3F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Semua Petugas')),
                  ..._daftarPetugas.map((u) => DropdownMenuItem<int?>(
                        value: u['id'],
                        child: Text(u['name']),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _filterUserId = value);
                  _muatUlang();
                },
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _muatUlang(),
              child: FutureBuilder<List<TitikLokasi>>(
                future: _futureRiwayat,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(child: Text('Error: ${snapshot.error}')),
                      ],
                    );
                  }
                  final riwayat = snapshot.data ?? [];
                  if (riwayat.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              widget.assetId != null
                                  ? 'Belum ada riwayat lokasi untuk barang ini.'
                                  : (widget.hanyaHariIni ? 'Belum ada kegiatan hari ini.' : 'Belum ada riwayat peminjaman.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: riwayat.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _kartuRiwayat(riwayat[index]),
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
            child: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                widget.assetId != null
                    ? 'Riwayat Lokasi: ${widget.judulFilter ?? "Barang"}'
                    : (widget.hanyaHariIni ? 'Kegiatan Hari Ini' : 'Riwayat Perpindahan'),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const Spacer(),
          IconButton(
            onPressed: _muatUlang,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
    );
  }

  Widget _kartuRiwayat(TitikLokasi r) {
    final waktu = r.scannedAt.toLocal();
    final jenis = _JenisInfo.dari(r);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: jenis.warna.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(jenis.ikon, color: jenis.warna),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.namaBarang,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: biruTua)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration:
                          BoxDecoration(color: jenis.warna.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(jenis.label,
                          style: TextStyle(color: jenis.warna, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                Text('${r.kodeAset} • ${r.kategori}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.black45),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(r.lokasiInput,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${waktu.day}/${waktu.month}/${waktu.year} '
                  '${waktu.hour.toString().padLeft(2, '0')}:'
                  '${waktu.minute.toString().padLeft(2, '0')} WIB',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
                if (r.namaPeminjam != null && r.namaPeminjam!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 13, color: tombolCyan),
                      const SizedBox(width: 4),
                      Text('Peminjam: ${r.namaPeminjam}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
                // Ini bagian sinkronisasi yang diminta: jelas kelihatan siapa
                // yang melakukan aksi ini (bisa beda orang dari yang pertama
                // scan barang ini), jadi riwayat antar-petugas nyambung.
                if (r.namaPetugas != null && r.namaPetugas!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(jenis.ikonOrang, size: 13, color: Colors.black45),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(jenis.teksPelaku(r.namaPetugas!),
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ),
                    ],
                  ),
                ],
                if (r.catatan != null && r.catatan!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sticky_note_2_outlined, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r.catatan!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (r.statusSaatItu != null) ...[
                  const SizedBox(height: 6),
                  _StatusChip(status: r.statusSaatItu!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Info tampilan (label, warna, ikon) berdasarkan jenis transisi status
/// yang tersimpan di backend — dipakai supaya riwayat jelas bedain mana
/// aksi "pinjam" beneran vs "kembalikan" vs sekadar update lain.
class _JenisInfo {
  final String label;
  final Color warna;
  final IconData ikon;
  final IconData ikonOrang;
  final bool pengembalian;

  const _JenisInfo({
    required this.label,
    required this.warna,
    required this.ikon,
    required this.ikonOrang,
    required this.pengembalian,
  });

  String teksPelaku(String nama) {
    if (pengembalian) return 'Dikembalikan oleh: $nama';
    if (label == 'Dipinjam') return 'Dipinjamkan oleh: $nama';
    return 'Dicatat oleh: $nama';
  }

  static _JenisInfo dari(TitikLokasi r) {
    if (r.isPeminjaman) {
      return const _JenisInfo(
        label: 'Dipinjam',
        warna: Color(0xFFCC9A2E),
        ikon: Icons.arrow_upward_rounded,
        ikonOrang: Icons.badge_outlined,
        pengembalian: false,
      );
    }
    if (r.isPengembalian) {
      return const _JenisInfo(
        label: 'Dikembalikan',
        warna: Color(0xFF2E9E5B),
        ikon: Icons.arrow_downward_rounded,
        ikonOrang: Icons.assignment_return_outlined,
        pengembalian: true,
      );
    }
    return const _JenisInfo(
      label: 'Diperbarui',
      warna: Color(0xFF6C5CE7),
      ikon: Icons.qr_code_scanner,
      ikonOrang: Icons.badge_outlined,
      pengembalian: false,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _warna {
    switch (status.toLowerCase()) {
      case 'tersedia':
        return const Color(0xFF2E9E5B);
      case 'dipinjam':
        return const Color(0xFFCC9A2E);
      case 'rusak':
        return const Color(0xFFB03A3A);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _warna.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Status kini: $status',
        style: TextStyle(color: _warna, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
