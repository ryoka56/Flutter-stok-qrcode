import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/refrescable.dart';
import 'tambah_barang_screen.dart';
import 'detail_barang_screen.dart';
import 'cetak_qr_screen.dart';
import 'riwayat_screen.dart';
import 'sampah_screen.dart';
import '../services/download_helper.dart';

/// Dashboard Pengaturan — versi baru.
/// Semua sub-menu "Kelola X" (Ruangan, Barang, Kategori, Akun) sekarang
/// ditampilkan dalam satu layout seragam persis seperti referensi desain:
/// topbar cyan + kotak cari, baris breadcrumb "Kelola X", tabel 2 kolom
/// dengan tombol hapus, dan tombol "+ Tambah X" mengambang di kanan bawah.
class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

enum _TabKelola { ruangan, barang, kategori, akun, pegawai }

class _PengaturanScreenState extends State<PengaturanScreen> implements Refrescable {
  static const Color tombolCyan = Color(0xFF29C5E8);
  static const Color biruTua = Color(0xFF16213E);

  _TabKelola _tabAktif = _TabKelola.ruangan;
  String _pencarian = '';
  bool _cariTerbuka = false;
  final _cariController = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _ruangans = [];
  List<Map<String, dynamic>> _kategoris = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _pegawais = [];
  List<Asset> _assets = []; // SEMUA aset (dipakai buat hitung rekap per ruangan/kategori)
  Map<String, int> _jumlahBarangPerRuangan = {};

  // --- Khusus tab "Kelola Barang": daftar terpaginasi (bukan _assets di atas) ---
  static const int _perPageBarang = 15;
  final ScrollController _scrollBarang = ScrollController();
  Timer? _debounceBarang;
  List<Asset> _assetsBarang = [];
  int _halamanBarang = 1;
  bool _masihAdaLagiBarang = true;
  bool _loadingBarangAwal = true;
  bool _loadingBarangLagi = false;
  bool _errorBarang = false;
  int _totalBarang = 0;
  String? _kategoriFilterBarang;
  String? _ruanganFilterBarang;

  // Mode pilih & hapus banyak sekaligus (khusus tab Barang)
  bool _modePilihBarang = false;
  final Set<int> _idBarangTerpilih = {};

  @override
  void initState() {
    super.initState();
    _muatSemua();
    _muatBarangAwal();
    _scrollBarang.addListener(_onScrollBarang);
  }

  @override
  void dispose() {
    _scrollBarang.removeListener(_onScrollBarang);
    _scrollBarang.dispose();
    _debounceBarang?.cancel();
    _cariController.dispose();
    super.dispose();
  }

  @override
  Future<void> refreshDiam() async {
    await Future.wait([
      _muatSemua(tampilkanLoading: false),
      _muatBarangAwal(cari: _tabAktif == _TabKelola.barang ? _cariController.text : null),
    ]);
  }

  void _onScrollBarang() {
    if (!_masihAdaLagiBarang || _loadingBarangLagi || _loadingBarangAwal) return;
    if (_scrollBarang.position.pixels >= _scrollBarang.position.maxScrollExtent - 200) {
      _muatBarangLagi();
    }
  }

  // Muat ulang daftar barang dari halaman 1 (dipakai saat refresh, cari, ganti filter)
  Future<void> _muatBarangAwal({String? cari}) async {
    setState(() {
      _loadingBarangAwal = true;
      _errorBarang = false;
      _halamanBarang = 1;
      _assetsBarang = [];
      _idBarangTerpilih.clear();
    });
    try {
      final hasil = await ApiService.getAssets(
        cari: cari,
        kategori: _kategoriFilterBarang,
        ruangan: _ruanganFilterBarang,
        page: 1,
        perPage: _perPageBarang,
      );
      if (mounted) {
        setState(() {
          _assetsBarang = hasil.data;
          _halamanBarang = hasil.currentPage;
          _masihAdaLagiBarang = hasil.masihAdaHalamanBerikutnya;
          _totalBarang = hasil.total;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorBarang = true);
    } finally {
      if (mounted) setState(() => _loadingBarangAwal = false);
    }
  }

  // Muat halaman berikutnya (dipanggil otomatis saat gulir ke bawah)
  Future<void> _muatBarangLagi() async {
    setState(() => _loadingBarangLagi = true);
    try {
      final hasil = await ApiService.getAssets(
        cari: _cariController.text,
        kategori: _kategoriFilterBarang,
        ruangan: _ruanganFilterBarang,
        page: _halamanBarang + 1,
        perPage: _perPageBarang,
      );
      if (mounted) {
        setState(() {
          _assetsBarang.addAll(hasil.data);
          _halamanBarang = hasil.currentPage;
          _masihAdaLagiBarang = hasil.masihAdaHalamanBerikutnya;
          _totalBarang = hasil.total;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memuat barang selanjutnya: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingBarangLagi = false);
    }
  }

  void _masukModePilihBarang(int idAwal) {
    setState(() {
      _modePilihBarang = true;
      _idBarangTerpilih.add(idAwal);
    });
  }

  void _keluarModePilihBarang() {
    setState(() {
      _modePilihBarang = false;
      _idBarangTerpilih.clear();
    });
  }

  void _toggleAmbilSemuaBarang() {
    setState(() {
      if (_idBarangTerpilih.length == _assetsBarang.length) {
        _idBarangTerpilih.clear();
      } else {
        _idBarangTerpilih
          ..clear()
          ..addAll(_assetsBarang.map((a) => a.id));
      }
    });
  }

  Future<void> _hapusBarangTerpilih() async {
    final jumlah = _idBarangTerpilih.length;
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus barang terpilih?'),
        content: Text('$jumlah barang akan dihapus permanen. Yakin lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB03A3A)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    try {
      final dihapus = await ApiService.hapusAssetBanyak(_idBarangTerpilih.toList());
      _keluarModePilihBarang();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$dihapus barang berhasil dihapus')));
      }
      _muatBarangAwal(cari: _cariController.text);
      _muatSemua(tampilkanLoading: false); // sinkronkan rekap jumlah per ruangan/kategori
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  Future<void> _muatSemua({bool tampilkanLoading = true}) async {
    if (tampilkanLoading) setState(() => _loading = true);
    try {
      final hasil = await Future.wait([
        ApiService.getRuangans(),
        ApiService.getKategoris(),
        ApiService.getUsers(),
        ApiService.getPegawais(),
        ApiService.getAllAssets(), // tetap perlu daftar lengkap buat fitur Cetak QR semua barang
        ApiService.getRekap(), // rekap jumlah per ruangan/kategori dihitung backend
      ]);
      final ruangans = hasil[0] as List<Map<String, dynamic>>;
      final kategoris = hasil[1] as List<Map<String, dynamic>>;
      final users = hasil[2] as List<Map<String, dynamic>>;
      final pegawais = hasil[3] as List<Map<String, dynamic>>;
      final assets = hasil[4] as List<Asset>;
      final rekap = hasil[5] as RekapAset;

      for (final k in kategoris) {
        k['jumlah_barang'] = rekap.perKategori[k['nama_kategori']] ?? 0;
      }

      if (mounted) {
        setState(() {
          _ruangans = ruangans;
          _kategoris = kategoris;
          _users = users;
          _pegawais = pegawais;
          _assets = assets;
          _jumlahBarangPerRuangan = rekap.perRuangan;
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

  // ---------------------------------------------------------------------
  // Aksi tambah & hapus per jenis data
  // ---------------------------------------------------------------------

  Future<void> _tambahRuangan() async {
    final namaController = TextEditingController();
    final lokasiController = TextEditingController();
    final keteranganController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final berhasil = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Ruangan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama Ruangan'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: lokasiController,
                decoration: const InputDecoration(labelText: 'Lokasi Gedung (opsional)'),
              ),
              TextFormField(
                controller: keteranganController,
                decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiService.tambahRuangan(
                  namaRuangan: namaController.text.trim(),
                  lokasiGedung:
                      lokasiController.text.trim().isEmpty ? null : lokasiController.text.trim(),
                  keterangan: keteranganController.text.trim().isEmpty
                      ? null
                      : keteranganController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (berhasil == true) _muatSemua();
  }

  Future<void> _hapusRuangan(int id, String nama) async {
    if (!await _konfirmasiHapus('Ruangan', nama)) return;
    try {
      await ApiService.hapusRuangan(id);
      _muatSemua();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _hapusBarang(int id, String nama) async {
    if (!await _konfirmasiHapus('Barang', nama)) return;
    try {
      await ApiService.hapusAsset(id);
      _muatSemua(tampilkanLoading: false);
      _muatBarangAwal(cari: _cariController.text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Export laporan barang ke Excel/PDF — hanya admin (halaman ini memang
  /// khusus admin). Backend akan sertakan rincian detail tiap aset
  /// (kode, kategori, ruangan, status, dsb) di file yang dihasilkan.
  ///
  /// PENTING: file diambil lewat request ber-autentikasi langsung dari
  /// dalam app (header Authorization asli), BUKAN dengan membuka tab
  /// browser baru. Cara lama (buka tab baru + sisip token di URL) rawan
  /// gagal karena tab baru tidak selalu bisa dipastikan bawa token dengan
  /// benar. Dengan cara ini, hasilnya sama persis kayak request API biasa
  /// yang sudah pasti berhasil di seluruh bagian app lain.
  Future<void> _exportLaporan(String tipe) async {
    final pesanLoading = ScaffoldMessenger.of(context);
    pesanLoading.showSnackBar(const SnackBar(content: Text('Menyiapkan laporan...'), duration: Duration(seconds: 2)));
    try {
      final path = tipe == 'excel' ? '/reports/excel' : '/reports/pdf';
      final headers = await ApiService.getAuthHeaders();
      final res = await http.get(Uri.parse('${ApiService.baseUrl}$path'), headers: headers);

      if (res.statusCode == 401) {
        throw Exception('Sesi login sudah habis. Silakan logout lalu login ulang.');
      }
      if (res.statusCode != 200) {
        throw Exception('Gagal mengambil laporan (kode ${res.statusCode}).');
      }

      final ekstensi = tipe == 'excel' ? 'csv' : 'pdf';
      final mime = tipe == 'excel' ? 'text/csv' : 'application/pdf';
      final namaFile = 'laporan-aset-${DateTime.now().millisecondsSinceEpoch}.$ekstensi';
      await downloadBytes(res.bodyBytes, namaFile, mime);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan berhasil diunduh.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _tambahKategori() async {
    final namaController = TextEditingController();
    final keteranganController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final berhasil = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama Kategori'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: keteranganController,
                decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiService.tambahKategori(
                  namaKategori: namaController.text.trim(),
                  keterangan: keteranganController.text.trim().isEmpty
                      ? null
                      : keteranganController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (berhasil == true) _muatSemua();
  }

  Future<void> _hapusKategori(int id, String nama) async {
    if (!await _konfirmasiHapus('Barang', nama)) return;
    try {
      await ApiService.hapusKategori(id);
      _muatSemua();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _tambahPegawai() async {
    final namaController = TextEditingController();
    final jabatanController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final berhasil = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Pegawai'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama Pegawai'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: jabatanController,
                decoration: const InputDecoration(labelText: 'Jabatan (opsional)'),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nama ini akan muncul di pilihan "Nama Peminjam" saat petugas scan barang untuk dipinjamkan.',
                  style: TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiService.tambahPegawai(
                  namaPegawai: namaController.text.trim(),
                  jabatan: jabatanController.text.trim().isEmpty ? null : jabatanController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (berhasil == true) _muatSemua();
  }

  Future<void> _hapusPegawai(int id, String nama) async {
    if (!await _konfirmasiHapus('Pegawai', nama)) return;
    try {
      await ApiService.hapusPegawai(id);
      _muatSemua();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _tambahAkun() async {
    final namaController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'petugas';
    final formKey = GlobalKey<FormState>();

    final berhasil = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Tambah Akun'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: namaController,
                    decoration: const InputDecoration(labelText: 'Nama'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Petugas'),
                          value: 'petugas',
                          groupValue: role,
                          onChanged: (v) => setStateDialog(() => role = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Admin'),
                          value: 'admin',
                          groupValue: role,
                          onChanged: (v) => setStateDialog(() => role = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ApiService.tambahUser(
                    name: namaController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    role: role,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (berhasil == true) _muatSemua();
  }

  Future<void> _hapusAkun(int id, String nama) async {
    if (!await _konfirmasiHapus('Akun', nama)) return;
    try {
      await ApiService.hapusUser(id);
      _muatSemua();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _labelStatus(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
        return 'Tersedia';
      case 'dipinjam':
        return 'Dipinjam';
      case 'rusak':
        return 'Rusak';
      default:
        return status;
    }
  }

  Color _warnaStatus(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
        return const Color(0xFF2E9E5B);
      case 'dipinjam':
        return const Color(0xFFCC9A2E);
      case 'rusak':
        return const Color(0xFFB03A3A);
      default:
        return Colors.black45;
    }
  }

  Future<bool> _konfirmasiHapus(String jenis, String nama) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $jenis?'),
        content: Text('"$nama" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return konfirmasi == true;
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Column(
        children: [
          _buildTopbar(),
          _buildBreadcrumb(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      _buildKontenTab(),
                      if (!_modePilihBarang)
                        Positioned(right: 20, bottom: 20, child: _tombolTambah()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopbar() {
    if (_modePilihBarang) {
      final semuaTerpilih = _idBarangTerpilih.length == _assetsBarang.length && _assetsBarang.isNotEmpty;
      return Container(
        color: const Color(0xFF16213E),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _keluarModePilihBarang,
            ),
            Expanded(
              child: Text('${_idBarangTerpilih.length} dipilih',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            IconButton(
              tooltip: semuaTerpilih ? 'Batalkan semua' : 'Pilih semua',
              icon: Icon(semuaTerpilih ? Icons.deselect : Icons.select_all, color: Colors.white),
              onPressed: _toggleAmbilSemuaBarang,
            ),
            IconButton(
              tooltip: 'Hapus terpilih',
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _idBarangTerpilih.isEmpty ? null : _hapusBarangTerpilih,
            ),
          ],
        ),
      );
    }

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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Dashboard Pengaturan',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          // Sembunyikan tombol Export waktu kotak cari lagi kebuka, biar gak
          // rebutan tempat & bikin overflow di layar sempit.
          if (_tabAktif == _TabKelola.barang && !_cariTerbuka) ...[
            _tombolFilterKategori(),
            const SizedBox(width: 8),
            _tombolPilihBanyak(),
            const SizedBox(width: 8),
            _tombolCetakQr(),
            const SizedBox(width: 8),
            _tombolExport(),
            const SizedBox(width: 8),
            _tombolSampah(),
            const SizedBox(width: 8),
          ],
          _kotakCari(),
        ],
      ),
    );
  }

  Widget _tombolSampah() {
    return _tombolIkonBulat(
      ikon: Icons.delete_sweep_outlined,
      tooltip: 'Barang Terhapus (Sampah)',
      onTap: () async {
        final adaPerubahan = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SampahScreen()));
        if (adaPerubahan == true) {
          _muatSemua(tampilkanLoading: false);
          _muatBarangAwal(cari: _cariController.text);
        }
      },
    );
  }

  Widget _tombolFilterKategori() {
    final aktif = _kategoriFilterBarang != null || _ruanganFilterBarang != null;
    return _tombolIkonBulat(
      ikon: Icons.filter_list,
      tooltip: 'Filter kategori & ruangan',
      aktif: aktif,
      onTap: _bukaDialogFilterBarang,
    );
  }

  Future<void> _bukaDialogFilterBarang() async {
    String? kategoriSementara = _kategoriFilterBarang;
    String? ruanganSementara = _ruanganFilterBarang;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Barang'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kategori', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String?>(
                    value: kategoriSementara,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Semua kategori')),
                      ..._kategoris.map((k) => DropdownMenuItem<String?>(
                            value: k['nama_kategori'] as String,
                            child: Text(k['nama_kategori'] as String),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => kategoriSementara = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ruangan', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String?>(
                    value: ruanganSementara,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Semua ruangan')),
                      ..._ruangans.map((r) => DropdownMenuItem<String?>(
                            value: r['nama_ruangan'] as String,
                            child: Text(r['nama_ruangan'] as String),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => ruanganSementara = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      kategoriSementara = null;
                      ruanganSementara = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: tombolCyan),
                  onPressed: () {
                    setState(() {
                      _kategoriFilterBarang = kategoriSementara;
                      _ruanganFilterBarang = ruanganSementara;
                    });
                    Navigator.pop(context);
                    _muatBarangAwal(cari: _cariController.text);
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tombolPilihBanyak() {
    return _tombolIkonBulat(
      ikon: Icons.checklist_rounded,
      tooltip: 'Pilih & hapus banyak barang',
      onTap: () {
        if (_assetsBarang.isEmpty) return;
        setState(() => _modePilihBarang = true);
      },
    );
  }

  Widget _tombolCetakQr() {
    return _tombolIkonBulat(
      ikon: Icons.qr_code_2_rounded,
      tooltip: 'Cetak QR Code',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CetakQrScreen(semuaAsset: _assets)),
      ),
    );
  }

  Widget _tombolIkonBulat({required IconData ikon, required String tooltip, required VoidCallback onTap, bool aktif = false}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: aktif ? const Color(0xFF16213E) : Colors.white, shape: BoxShape.circle),
          child: Icon(ikon, size: 18, color: aktif ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _tombolExport() {
    return PopupMenuButton<String>(
      tooltip: 'Export Laporan Barang',
      onSelected: _exportLaporan,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'excel', child: Text('Export ke Excel (CSV)')),
        PopupMenuItem(value: 'pdf', child: Text('Export ke PDF')),
      ],
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.file_download_outlined, size: 18, color: Colors.black87),
      ),
    );
  }

  Widget _kotakCari() {
    if (_cariTerbuka) {
      return Flexible(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200, minWidth: 90),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _cariController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Cari...',
                    hintStyle: TextStyle(fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) {
                    setState(() => _pencarian = v.toLowerCase());
                    if (_tabAktif == _TabKelola.barang) {
                      // Barang pakai pencarian di server (data ribuan), jadi
                      // di-debounce dulu biar gak nembak API tiap ketukan huruf.
                      _debounceBarang?.cancel();
                      _debounceBarang = Timer(const Duration(milliseconds: 400), () {
                        _muatBarangAwal(cari: v);
                      });
                    }
                  },
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _cariTerbuka = false;
                  _pencarian = '';
                  _cariController.clear();
                  if (_tabAktif == _TabKelola.barang) _muatBarangAwal();
                }),
                child: const Icon(Icons.close, size: 16, color: Colors.black45),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _cariTerbuka = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cari', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            SizedBox(width: 6),
            Icon(Icons.search, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    Widget tab(_TabKelola nilai, String label) {
      final aktif = _tabAktif == nilai;
      return GestureDetector(
        onTap: () => setState(() {
          _tabAktif = nilai;
          _pencarian = '';
          _cariController.clear();
          _cariTerbuka = false;
          _modePilihBarang = false;
          _idBarangTerpilih.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          margin: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: aktif ? tombolCyan : Colors.transparent, width: 2.5)),
          ),
          child: Text('Kelola $label',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: aktif ? FontWeight.bold : FontWeight.w500,
                  color: aktif ? biruTua : Colors.black45)),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            tab(_TabKelola.ruangan, 'Ruangan'),
            tab(_TabKelola.barang, 'Barang'),
            tab(_TabKelola.kategori, 'Kategori'),
            tab(_TabKelola.akun, 'Akun'),
            tab(_TabKelola.pegawai, 'Pegawai'),
          ],
        ),
      ),
    );
  }

  Widget _buildKontenTab() {
    switch (_tabAktif) {
      case _TabKelola.ruangan:
        final data = _ruangans
            .where((r) => (r['nama_ruangan'] ?? '').toString().toLowerCase().contains(_pencarian))
            .toList();
        return _tabelKelola(
          kolomKiri: 'Nama Ruangan',
          kolomKanan: 'Jumlah Barang',
          items: data
              .map((r) => _BarisData(
                    id: r['id'],
                    judul: r['nama_ruangan'] ?? '-',
                    subjudul: r['lokasi_gedung'],
                    nilaiKanan: '${_jumlahBarangPerRuangan[r['nama_ruangan']] ?? 0}',
                    ikon: Icons.meeting_room_rounded,
                    onHapus: () => _hapusRuangan(r['id'], r['nama_ruangan'] ?? '-'),
                  ))
              .toList(),
          pesanKosong: 'Belum ada ruangan. Tambahkan lewat tombol di kanan bawah.',
        );

      case _TabKelola.barang:
        return _buildTabBarangList();

      case _TabKelola.kategori:
        final data = _kategoris
            .where((k) => (k['nama_kategori'] ?? '').toString().toLowerCase().contains(_pencarian))
            .toList();
        return _tabelKelola(
          kolomKiri: 'Nama Kategori',
          kolomKanan: 'Jumlah Barang',
          items: data
              .map((k) => _BarisData(
                    id: k['id'],
                    judul: k['nama_kategori'] ?? '-',
                    subjudul: k['keterangan'],
                    nilaiKanan: '${k['jumlah_barang'] ?? 0}',
                    ikon: Icons.category_rounded,
                    onHapus: () => _hapusKategori(k['id'], k['nama_kategori'] ?? '-'),
                  ))
              .toList(),
          pesanKosong: 'Belum ada kategori. Tambahkan lewat tombol di kanan bawah.',
        );

      case _TabKelola.akun:
        final data = _users
            .where((u) =>
                (u['name'] ?? '').toString().toLowerCase().contains(_pencarian) ||
                (u['email'] ?? '').toString().toLowerCase().contains(_pencarian))
            .toList();
        return _tabelKelola(
          kolomKiri: 'Akun',
          kolomKanan: 'Kategori',
          items: data
              .map((u) => _BarisData(
                    id: u['id'],
                    judul: u['name'] ?? '-',
                    subjudul: u['email'],
                    nilaiKanan: (u['role'] == 'admin') ? 'Admin' : 'Petugas',
                    ikon: (u['role'] == 'admin') ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                    isAvatar: true,
                    onHapus: () => _hapusAkun(u['id'], u['name'] ?? '-'),
                  ))
              .toList(),
          pesanKosong: 'Belum ada akun. Tambahkan lewat tombol di kanan bawah.',
        );

      case _TabKelola.pegawai:
        final data = _pegawais
            .where((p) => (p['nama_pegawai'] ?? '').toString().toLowerCase().contains(_pencarian))
            .toList();
        return _tabelKelola(
          kolomKiri: 'Nama Pegawai',
          kolomKanan: 'Jabatan',
          items: data
              .map((p) => _BarisData(
                    id: p['id'],
                    judul: p['nama_pegawai'] ?? '-',
                    nilaiKanan: p['jabatan'] ?? '-',
                    ikon: Icons.badge_rounded,
                    onHapus: () => _hapusPegawai(p['id'], p['nama_pegawai'] ?? '-'),
                  ))
              .toList(),
          pesanKosong:
              'Belum ada pegawai. Tambahkan lewat tombol di kanan bawah supaya muncul di pilihan "Nama Peminjam" saat scan.',
        );
    }
  }

  /// Daftar khusus tab "Kelola Barang": beda dari _tabelKelola karena butuh
  /// paginasi 15/halaman (infinite-scroll) & mode pilih banyak buat hapus
  /// massal — dua fitur yang tidak dibutuhkan tab Ruangan/Kategori/Akun.
  Widget _buildTabBarangList() {
    if (_loadingBarangAwal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorBarang) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat data barang.'),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _muatBarangAwal(cari: _cariController.text), child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (_assetsBarang.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _muatBarangAwal(cari: _cariController.text),
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text(
                (_kategoriFilterBarang != null || _ruanganFilterBarang != null || _cariController.text.isNotEmpty)
                    ? 'Tidak ada barang yang cocok.'
                    : 'Belum ada barang. Tambahkan lewat tombol di kanan bawah.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black38),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _muatBarangAwal(cari: _cariController.text),
      child: ListView(
        controller: _scrollBarang,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text('Menampilkan ${_assetsBarang.length} dari $_totalBarang barang',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(_assetsBarang.length, (i) {
                final a = _assetsBarang[i];
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, color: Color(0xFFF0F1F5)),
                    _barisBarang(a),
                  ],
                );
              }),
            ),
          ),
          _buildFooterBarang(),
        ],
      ),
    );
  }

  Widget _buildFooterBarang() {
    if (_loadingBarangLagi) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!_masihAdaLagiBarang) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('— Semua barang sudah ditampilkan —',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  /// Info lokasi barang: SELALU tampilkan posisi awal (diisi admin waktu
  /// Tambah Barang) DAN lokasi terakhir hasil scan berdampingan, biar
  /// kelihatan jelas apakah barang sudah berpindah dari posisi awalnya.
  /// Tap buat buka riwayat lokasi lengkap barang ini (sinkron sama tab
  /// Riwayat, sama-sama ambil dari data scan_logs yang sama).
  Widget _infoLokasi(Asset a) {
    final sudahDiscan = a.lokasiTerakhir != null;
    final posisiAwal = a.ruanganAsal ?? '-';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RiwayatScreen(assetId: a.id, judulFilter: a.namaBarang)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_outlined, size: 12, color: Colors.black45),
              const SizedBox(width: 3),
              Flexible(
                child: Text('Awal: $posisiAwal',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 12, color: sudahDiscan ? tombolCyan : Colors.orange.shade700),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  sudahDiscan ? 'Terakhir: ${a.lokasiTerakhir!.lokasiInput}' : 'Terakhir: belum discan',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: sudahDiscan ? tombolCyan : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, size: 13, color: Colors.grey.shade400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barisBarang(Asset a) {
    final terpilih = _idBarangTerpilih.contains(a.id);
    return InkWell(
      onTap: () async {
        if (_modePilihBarang) {
          setState(() {
            if (terpilih) {
              _idBarangTerpilih.remove(a.id);
            } else {
              _idBarangTerpilih.add(a.id);
            }
          });
          return;
        }
        final perluRefresh = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailBarangScreen(asset: a, isAdmin: true)),
        );
        if (perluRefresh == true) {
          _muatSemua(tampilkanLoading: false);
          _muatBarangAwal(cari: _cariController.text);
        }
      },
      onLongPress: !_modePilihBarang ? () => _masukModePilihBarang(a.id) : null,
      child: Container(
        color: terpilih ? tombolCyan.withOpacity(0.08) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _modePilihBarang
                        ? Checkbox(
                            value: terpilih,
                            activeColor: tombolCyan,
                            onChanged: (_) {
                              setState(() {
                                if (terpilih) {
                                  _idBarangTerpilih.remove(a.id);
                                } else {
                                  _idBarangTerpilih.add(a.id);
                                }
                              });
                            },
                          )
                        : (a.fotoUtama != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(a.fotoUtama!, width: 33, height: 33, fit: BoxFit.cover),
                              )
                            : Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: tombolCyan.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.inventory_2_rounded, size: 17, color: tombolCyan),
                              )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(a.namaBarang,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF16213E))),
                          Text('${a.kodeAset} • ${a.kategori}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
                          const SizedBox(height: 2),
                          _infoLokasi(a),
                          if (a.status == 'dipinjam' && a.peminjamSaatIni != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, size: 12, color: Color(0xFFCC9A2E)),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text('Dipinjam: ${a.peminjamSaatIni}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFFCC9A2E), fontWeight: FontWeight.w600)),
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
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _warnaStatus(a.status).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(_labelStatus(a.status),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _warnaStatus(a.status))),
                  ),
                ),
              ),
              if (!_modePilihBarang)
                SizedBox(
                  width: 88,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, color: tombolCyan, size: 20),
                        tooltip: 'Cetak QR',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CetakQrScreen(semuaAsset: _assets, assetAwal: a)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD9534F), size: 20),
                        tooltip: 'Hapus',
                        onPressed: () => _hapusBarang(a.id, a.namaBarang),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Layout tabel generik: header 2 kolom + baris data (icon/avatar, judul,
  /// subjudul kecil, nilai kanan, tombol hapus) — dipakai oleh tab
  /// Ruangan/Kategori/Akun supaya tampilannya seragam persis seperti
  /// referensi desain (tab Barang pakai _buildTabBarangList sendiri di atas).
  Widget _tabelKelola({
    required String kolomKiri,
    required String kolomKanan,
    required List<_BarisData> items,
    required String pesanKosong,
  }) {
    return RefreshIndicator(
      onRefresh: _muatSemua,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(kolomKiri,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(kolomKanan,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(pesanKosong, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black38)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, color: Color(0xFFF0F1F5)),
                      _barisTabel(item),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barisTabel(_BarisData item) {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  item.isAvatar
                      ? CircleAvatar(
                          radius: 16,
                          backgroundColor: tombolCyan.withOpacity(0.15),
                          child: Icon(item.ikon, size: 17, color: tombolCyan),
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: tombolCyan.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(item.ikon, size: 17, color: tombolCyan),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.judul,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF16213E))),
                        if (item.subjudul != null && item.subjudul.toString().trim().isNotEmpty)
                          Text(item.subjudul.toString(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: item.warnaNilaiKanan != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: item.warnaNilaiKanan!.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(item.nilaiKanan,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold, color: item.warnaNilaiKanan)),
                      )
                    : Text(item.nilaiKanan, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ),
            SizedBox(
              width: item.onCetak != null ? 88 : 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.onCetak != null)
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, color: tombolCyan, size: 20),
                      onPressed: item.onCetak,
                      tooltip: 'Cetak QR',
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD9534F), size: 20),
                    onPressed: item.onHapus,
                    tooltip: 'Hapus',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolTambah() {
    String label;
    VoidCallback onTap;
    switch (_tabAktif) {
      case _TabKelola.ruangan:
        label = 'Tambah Ruangan';
        onTap = _tambahRuangan;
        break;
      case _TabKelola.barang:
        label = 'Tambah Barang';
        onTap = () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TambahBarangScreen()));
          _muatSemua(tampilkanLoading: false);
          _muatBarangAwal(cari: _cariController.text);
        };
        break;
      case _TabKelola.kategori:
        label = 'Tambah Kategori';
        onTap = _tambahKategori;
        break;
      case _TabKelola.akun:
        label = 'Tambah Akun';
        onTap = _tambahAkun;
        break;
      case _TabKelola.pegawai:
        label = 'Tambah Pegawai';
        onTap = _tambahPegawai;
        break;
    }

    return Material(
      color: tombolCyan,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: tombolCyan.withOpacity(0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.black87, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarisData {
  final int id;
  final String judul;
  final dynamic subjudul;
  final String nilaiKanan;
  final Color? warnaNilaiKanan;
  final IconData ikon;
  final bool isAvatar;
  final VoidCallback? onCetak;
  final VoidCallback onHapus;

  _BarisData({
    required this.id,
    required this.judul,
    this.subjudul,
    required this.nilaiKanan,
    this.warnaNilaiKanan,
    required this.ikon,
    this.isAvatar = false,
    this.onCetak,
    required this.onHapus,
  });
}
