import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/asset.dart';
import '../models/titik_lokasi.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/refrescable.dart';
import 'scan_screen.dart';
import 'riwayat_screen.dart';
import 'statistik_screen.dart';
import 'informasi_screen.dart';
import 'peta_screen.dart';

class TinjauanScreen extends StatefulWidget {
  const TinjauanScreen({super.key});

  @override
  State<TinjauanScreen> createState() => _TinjauanScreenState();
}

class _TinjauanScreenState extends State<TinjauanScreen> implements Refrescable {
  static const Color tombolCyan = Color(0xFF29C5E8);
  static const Color biruTua = Color(0xFF16213E);

  String? _nama;
  bool _loading = true;
  Map<String, dynamic>? _statHarian;
  Map<String, dynamic>? _statBulanan;
  Map<String, dynamic>? _statSemua;
  RekapAset? _rekap;

  // Grafik: 'mingguan' | 'bulanan' | 'tahunan'
  String _periodeGrafik = 'bulanan';
  Map<String, dynamic>? _grafik;
  bool _loadingGrafik = false;

  // Peta lokasi semua barang hasil scan seluruh petugas
  List<TitikLokasi> _titikLokasi = [];
  bool _loadingPeta = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _muatSemua();
    _muatGrafik();
    _muatPeta();
  }

  /// Dipanggil MainNavigationScreen setiap kali menu "Tinjauan" diklik.
  /// Data lama tetap tampil di layar (tidak nge-blank/loading penuh) sambil
  /// versi terbaru diambil di belakang layar lalu diganti begitu selesai.
  @override
  Future<void> refreshDiam() async {
    await Future.wait([
      _muatSemua(tampilkanLoading: false),
      _muatGrafik(tampilkanLoading: false),
      _muatPeta(tampilkanLoading: false),
    ]);
  }

  Future<void> _muatSemua({bool tampilkanLoading = true}) async {
    if (tampilkanLoading) setState(() => _loading = true);
    try {
      // Semua request independen -> jalankan BARENGAN (bukan satu-satu),
      // jadi total waktu tunggu = request paling lambat, bukan jumlah semua.
      final hasil = await Future.wait([
        AuthService.getNama(),
        ApiService.getStatistik(periode: 'harian'),
        ApiService.getStatistik(periode: 'bulanan'),
        ApiService.getStatistik(periode: 'semua'),
        ApiService.getRekap(),
      ]);
      final nama = hasil[0] as String?;
      final harian = hasil[1] as Map<String, dynamic>;
      final bulanan = hasil[2] as Map<String, dynamic>;
      final semua = hasil[3] as Map<String, dynamic>;
      final rekap = hasil[4] as RekapAset;

      if (mounted) {
        setState(() {
          _nama = (nama != null && nama.isNotEmpty) ? nama : 'Admin';
          _statHarian = harian;
          _statBulanan = bulanan;
          _statSemua = semua;
          _rekap = rekap;
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

  Future<void> _muatGrafik({bool tampilkanLoading = true}) async {
    if (tampilkanLoading) setState(() => _loadingGrafik = true);
    try {
      final grafik = await ApiService.getGrafik(periode: _periodeGrafik);
      if (mounted) setState(() => _grafik = grafik);
    } catch (e) {
      if (mounted && tampilkanLoading) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat grafik: $e')));
      }
    } finally {
      if (mounted && tampilkanLoading) setState(() => _loadingGrafik = false);
    }
  }

  Future<void> _muatPeta({bool tampilkanLoading = true}) async {
    if (tampilkanLoading) setState(() => _loadingPeta = true);
    try {
      final titik = await ApiService.getPetaLokasi();
      if (mounted) setState(() => _titikLokasi = titik);
    } catch (_) {
      // gagal diam-diam, kartu peta akan menampilkan status kosong
    } finally {
      if (mounted && tampilkanLoading) setState(() => _loadingPeta = false);
    }
  }

  Future<void> _gantiPeriodeGrafik(String periode) async {
    if (periode == _periodeGrafik) return;
    setState(() => _periodeGrafik = periode);
    await _muatGrafik();
  }

  int _hitungStatus(String status) => _rekap?.perStatus[status] ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_muatSemua(), _muatGrafik(), _muatPeta()]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderBar(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKartuGrafik(),
                          const SizedBox(height: 20),
                          LayoutBuilder(builder: (context, constraints) {
                            final sempit = constraints.maxWidth < 700;
                            final kartu = [
                              _kartuStat(
                                judul: 'Kegiatan hari ini',
                                nilai: '${_statHarian?['total'] ?? 0}',
                                keterangan: 'peminjaman hari ini',
                                ikon: Icons.today_rounded,
                                warnaIkon: const Color(0xFF29C5E8),
                                onLainnya: () => Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => const RiwayatScreen(hanyaHariIni: true))),
                              ),
                              _kartuStatList(
                                judul: 'Alat teratas',
                                items: (_statBulanan?['barang_terpopuler'] as List? ?? [])
                                    .map((e) => e['nama_barang'].toString())
                                    .toList(),
                                ikon: Icons.star_rounded,
                                warnaIkon: const Color(0xFFE8A93A),
                                onLainnya: () => Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => const StatistikScreen())),
                              ),
                              _kartuStat(
                                judul: 'Total Bulan ini',
                                nilai: '${_statBulanan?['total'] ?? 0}',
                                keterangan: 'Total Keseluruhan: ${_statSemua?['total'] ?? 0}',
                                ikon: Icons.bar_chart_rounded,
                                warnaIkon: const Color(0xFF6C5CE7),
                                onLainnya: () => Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => const StatistikScreen())),
                              ),
                              _kartuStatus(
                                onLainnya: () => Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => const InformasiScreen())),
                              ),
                            ];
                            if (sempit) {
                              return GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.0,
                                children: kartu,
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: kartu
                                  .map((k) => Expanded(child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6), child: k)))
                                  .toList(),
                            );
                          }),
                          const SizedBox(height: 20),
                          _buildKartuPeta(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF29C5E8), Color(0xFF1FA9CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(color: tombolCyan.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Dashboard Tinjauan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Scan QR', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: biruTua,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKartuGrafik() {
    final sekarang = DateTime.now();
    final data = (_grafik?['data'] as List?) ?? [];
    final topItem = _grafik?['top_item'];
    final total = _grafik?['total'] ?? 0;

    // Sedikit longgar dibanding tinggi batang maksimum (110) supaya angka +
    // batang + label tidak overflow di bawah SizedBox.
    const tinggiArea = 150.0;
    const tinggiBarMax = 100.0;

    final maxJumlah = data.isEmpty
        ? 1.0
        : data.map((d) => (d['jumlah'] as num).toDouble()).fold(1.0, (a, b) => a > b ? a : b);

    // Untuk grafik "bulanan" (per tanggal, bisa 28-31 titik) grafiknya jadi
    // bisa digeser ke samping (lihat LayoutBuilder di bawah) biar tetap
    // rapi & kebaca, bukan dipaksa muat semua di layar sempit.

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16213E), Color(0xFF1D2C4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: biruTua.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 20, color: Colors.white70),
              children: [
                const TextSpan(text: 'Good Morning, '),
                TextSpan(text: '$_nama', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${sekarang.day}/${sekarang.month}/${sekarang.year}, '
            '${sekarang.hour.toString().padLeft(2, '0')}:${sekarang.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text('STATISTIK PEMINJAMAN',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              _togglePeriode(),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: tinggiArea,
            child: _loadingGrafik
                ? const Center(child: SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)))
                : data.isEmpty
                    ? const Center(
                        child: Text('Belum ada data peminjaman.',
                            style: TextStyle(color: Colors.white38, fontSize: 12)))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: data.length,
                        itemExtent: 36,
                        itemBuilder: (context, i) {
                          final titik = data[i] as Map<String, dynamic>;
                          final jumlah = (titik['jumlah'] as num).toDouble();
                          final tinggi = maxJumlah > 0 ? (jumlah / maxJumlah) * tinggiBarMax : 0.0;
                          final aktif = _apakahTitikIniSekarang(i, data.length);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _tampilkanDetailTitik(titik),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (jumlah > 0)
                                    Text('${jumlah.toInt()}',
                                        style: TextStyle(
                                            color: aktif ? Colors.white : Colors.white38, fontSize: 9)),
                                  const SizedBox(height: 3),
                                  Container(
                                    height: tinggi < 4 ? 4 : tinggi,
                                    decoration: BoxDecoration(
                                      color: aktif ? tombolCyan : Colors.white24,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(titik['label']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: aktif ? Colors.white : Colors.white38,
                                          fontSize: 10,
                                          fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 6),
          Text(
            data.length > 12
                ? 'Geser grafik ke samping untuk lihat titik lain. Ketuk untuk rincian per alat.'
                : 'Ketuk salah satu batang untuk melihat rincian per alat.',
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Peminjaman ${_labelPeriode()}: $total',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              if (topItem != null) ...[
                const SizedBox(height: 4),
                Text('Top Item: $topItem',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _labelPeriode() {
    switch (_periodeGrafik) {
      case 'mingguan':
        return 'Minggu Ini';
      case 'tahunan':
        return 'Tahun Ini';
      case 'bulanan':
      default:
        return 'Bulan Ini';
    }
  }

  bool _apakahTitikIniSekarang(int index, int panjang) {
    final sekarang = DateTime.now();
    switch (_periodeGrafik) {
      case 'mingguan':
        // Senin = index 0 ... Minggu = index 6 (mengikuti startOfWeek backend)
        final hariIni = sekarang.weekday - 1; // Senin=1 -> 0
        return index == hariIni;
      case 'tahunan':
        return (index + 1) == sekarang.month;
      case 'bulanan':
      default:
        return (index + 1) == sekarang.day;
    }
  }

  Widget _togglePeriode() {
    Widget tombol(String value, String label) {
      final aktif = _periodeGrafik == value;
      return GestureDetector(
        onTap: () => _gantiPeriodeGrafik(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: aktif ? tombolCyan : Colors.white10,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: aktif ? Colors.black87 : Colors.white60)),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tombol('mingguan', 'Mingguan'),
        const SizedBox(width: 6),
        tombol('bulanan', 'Bulanan'),
        const SizedBox(width: 6),
        tombol('tahunan', 'Tahunan'),
      ],
    );
  }

  void _tampilkanDetailTitik(Map<String, dynamic> titik) {
    final breakdown = (titik['breakdown'] as List? ?? []);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: biruTua,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${titik['label']} (${titik['tanggal'] ?? ''})',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total Peminjaman: ${titik['jumlah']}',
                style: const TextStyle(color: tombolCyan, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (breakdown.isEmpty)
              const Text('Tidak ada peminjaman pada periode ini.',
                  style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              ...breakdown.map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: tombolCyan, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${b['nama_barang']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                        Text('${b['jumlah']} Unit',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildKartuPeta() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: const Color(0xFF29C5E8).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.map_rounded, color: tombolCyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Peta Lokasi Barang',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text(
                        _loadingPeta
                            ? 'Memuat titik lokasi...'
                            : '${_titikLokasi.length} barang tercatat dari seluruh petugas',
                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PetaScreen())),
                  icon: const Icon(Icons.open_in_full_rounded, size: 15),
                  label: const Text('Peta Penuh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: tombolCyan),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 260,
            child: _loadingPeta
                ? const Center(child: CircularProgressIndicator())
                : _titikLokasi.isEmpty
                    ? Container(
                        color: const Color(0xFFF3F5F9),
                        alignment: Alignment.center,
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Belum ada barang yang pernah discan.\nTitik lokasi akan muncul di sini setelah\npetugas memindai & mencatat lokasi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45, fontSize: 12),
                          ),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(_titikLokasi.first.latitude, _titikLokasi.first.longitude),
                          initialZoom: 13,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.aset_gudang_komdigi',
                          ),
                          MarkerLayer(
                            markers: _titikLokasi.map((t) {
                              return Marker(
                                point: LatLng(t.latitude, t.longitude),
                                width: 42,
                                height: 42,
                                child: GestureDetector(
                                  onTap: () => _tampilkanDetailPeta(t),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.location_on_rounded, color: tombolCyan, size: 26),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _tampilkanDetailPeta(TitikLokasi t) {
    final waktuLokal = t.scannedAt.toLocal();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.namaBarang, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${t.kodeAset} • ${t.kategori}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 18, color: tombolCyan),
                const SizedBox(width: 6),
                Expanded(child: Text(t.lokasiInput)),
              ]),
              if (t.namaPetugas != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.badge_rounded, size: 18, color: Colors.black45),
                  const SizedBox(width: 6),
                  Text('Dicatat oleh: ${t.namaPetugas}', style: const TextStyle(color: Colors.black54)),
                ]),
              ],
              if (t.namaPeminjam != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.person_rounded, size: 18, color: Colors.black45),
                  const SizedBox(width: 6),
                  Text('Peminjam: ${t.namaPeminjam}', style: const TextStyle(color: Colors.black54)),
                ]),
              ],
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 18, color: Colors.black45),
                const SizedBox(width: 6),
                Text(
                  '${waktuLokal.day}/${waktuLokal.month}/${waktuLokal.year} '
                  '${waktuLokal.hour.toString().padLeft(2, '0')}:${waktuLokal.minute.toString().padLeft(2, '0')} WIB',
                  style: const TextStyle(color: Colors.black45),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tombolLainnya(VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: tombolCyan,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        icon: const Text('Lainnya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        label: const Icon(Icons.arrow_forward, size: 14),
      ),
    );
  }

  Widget _kartuStat({
    required String judul,
    required String nilai,
    required String keterangan,
    required IconData ikon,
    required Color warnaIkon,
    required VoidCallback onLainnya,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: warnaIkon.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(ikon, color: warnaIkon, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(judul, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ],
          ),
          const SizedBox(height: 12),
          Text(nilai, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF16213E))),
          Text(keterangan, style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 12),
          _tombolLainnya(onLainnya),
        ],
      ),
    );
  }

  Widget _kartuStatList({
    required String judul,
    required List<String> items,
    required IconData ikon,
    required Color warnaIkon,
    required VoidCallback onLainnya,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: warnaIkon.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(ikon, color: warnaIkon, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(judul, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ],
          ),
          const SizedBox(height: 10),
          ...items.take(4).toList().asMap().entries.map(
              (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 13)),
                  )),
          if (items.isEmpty) const Text('Belum ada data', style: TextStyle(fontSize: 12, color: Colors.black38)),
          const SizedBox(height: 12),
          _tombolLainnya(onLainnya),
        ],
      ),
    );
  }

  Widget _kartuStatus({required VoidCallback onLainnya}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF2E9E5B).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2E9E5B), size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Status Aset', style: TextStyle(fontSize: 12, color: Colors.black54))),
            ],
          ),
          const SizedBox(height: 10),
          _barisStatus('Tersedia', _hitungStatus('tersedia'), const Color(0xFF2E9E5B)),
          _barisStatus('Dipinjam', _hitungStatus('dipinjam'), const Color(0xFFCC9A2E)),
          _barisStatus('Rusak', _hitungStatus('rusak'), const Color(0xFFB03A3A)),
          const SizedBox(height: 12),
          _tombolLainnya(onLainnya),
        ],
      ),
    );
  }

  Widget _barisStatus(String label, int jumlah, Color warna) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: warna, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$jumlah', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
