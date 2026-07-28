import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'tambah_barang_screen.dart';
import 'detail_barang_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _perPage = 15;
  static const Color _biru = Color(0xFF3A8FC0);

  final _cariController = TextEditingController();
  final _scrollController = ScrollController();

  final List<Asset> _assets = [];
  List<String> _daftarKategori = [];
  String? _kategoriDipilih;
  String _kataCari = '';

  bool _isAdmin = false;
  bool _loadingAwal = true;
  bool _loadingLagi = false;
  bool _adaError = false;
  int _halaman = 1;
  bool _masihAdaHalamanBerikutnya = true;
  int _totalData = 0;

  // Mode pilih & hapus banyak sekaligus
  bool _modePilih = false;
  final Set<int> _idTerpilih = {};

  @override
  void initState() {
    super.initState();
    _cekRole();
    _muatKategori();
    _muatUlang();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cariController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_masihAdaHalamanBerikutnya || _loadingLagi || _loadingAwal) return;
    // Trigger sedikit sebelum benar-benar mentok bawah, biar terasa mulus
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _muatHalamanBerikutnya();
    }
  }

  Future<void> _cekRole() async {
    final admin = await AuthService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _muatKategori() async {
    try {
      final data = await ApiService.getKategoris();
      if (mounted) {
        setState(() {
          _daftarKategori = data.map((e) => e['nama_kategori'].toString()).toList();
        });
      }
    } catch (_) {
      // Filter kategori bukan fitur kritis, biarkan diam kalau gagal dimuat
    }
  }

  // Muat ulang dari halaman 1 (dipakai saat refresh, cari, atau ganti filter)
  Future<void> _muatUlang() async {
    setState(() {
      _loadingAwal = true;
      _adaError = false;
      _halaman = 1;
      _assets.clear();
      _idTerpilih.clear();
    });
    try {
      final hasil = await ApiService.getAssets(
        cari: _kataCari,
        kategori: _kategoriDipilih,
        page: 1,
        perPage: _perPage,
      );
      if (mounted) {
        setState(() {
          _assets.addAll(hasil.data);
          _halaman = hasil.currentPage;
          _masihAdaHalamanBerikutnya = hasil.masihAdaHalamanBerikutnya;
          _totalData = hasil.total;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _adaError = true);
    } finally {
      if (mounted) setState(() => _loadingAwal = false);
    }
  }

  // Muat halaman berikutnya (dipanggil otomatis saat digulir ke bawah)
  Future<void> _muatHalamanBerikutnya() async {
    setState(() => _loadingLagi = true);
    try {
      final hasil = await ApiService.getAssets(
        cari: _kataCari,
        kategori: _kategoriDipilih,
        page: _halaman + 1,
        perPage: _perPage,
      );
      if (mounted) {
        setState(() {
          _assets.addAll(hasil.data);
          _halaman = hasil.currentPage;
          _masihAdaHalamanBerikutnya = hasil.masihAdaHalamanBerikutnya;
          _totalData = hasil.total;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memuat data selanjutnya: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingLagi = false);
    }
  }

  Future<void> _exportLaporan(String tipe) async {
    final token = await AuthService.getToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sesi login tidak ditemukan. Silakan login ulang.')));
      }
      return;
    }
    final path = tipe == 'excel' ? '/reports/excel' : '/reports/pdf';
    final uri = Uri.parse('${ApiService.baseUrl}$path').replace(queryParameters: {'token': token});
    final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!berhasil && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka link laporan.')),
      );
    }
  }

  void _masukModePilih(int idAwal) {
    setState(() {
      _modePilih = true;
      _idTerpilih.add(idAwal);
    });
  }

  void _keluarModePilih() {
    setState(() {
      _modePilih = false;
      _idTerpilih.clear();
    });
  }

  void _toggleAmbilSemua() {
    setState(() {
      if (_idTerpilih.length == _assets.length) {
        _idTerpilih.clear();
      } else {
        _idTerpilih
          ..clear()
          ..addAll(_assets.map((a) => a.id));
      }
    });
  }

  Future<void> _hapusTerpilih() async {
    final jumlah = _idTerpilih.length;
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
      final dihapus = await ApiService.hapusAssetBanyak(_idTerpilih.toList());
      _keluarModePilih();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$dihapus barang berhasil dihapus')));
      }
      _muatUlang();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _modePilih ? _buildAppBarPilih() : _buildAppBarNormal(),
      body: Column(
        children: [
          if (!_modePilih) _buildPencarianDanFilter(),
          if (!_modePilih && !_isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mode petugas: hanya bisa melihat & scan barang',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          if (!_modePilih && !_loadingAwal && !_adaError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Menampilkan ${_assets.length} dari $_totalData barang',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          Expanded(child: _buildIsiList()),
        ],
      ),
      floatingActionButton: (_isAdmin && !_modePilih)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF29C5E8),
              foregroundColor: Colors.black87,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TambahBarangScreen()),
                );
                _muatUlang();
              },
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBarNormal() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      title: const Text('List Barang'),
      actions: [
        if (_isAdmin)
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export Laporan',
            onSelected: _exportLaporan,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'excel', child: Text('Export ke Excel (CSV)')),
              PopupMenuItem(value: 'pdf', child: Text('Export ke PDF')),
            ],
          ),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _muatUlang),
      ],
    );
  }

  PreferredSizeWidget _buildAppBarPilih() {
    final semuaTerpilih = _idTerpilih.length == _assets.length && _assets.isNotEmpty;
    return AppBar(
      backgroundColor: _biru,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.close), onPressed: _keluarModePilih),
      title: Text('${_idTerpilih.length} dipilih'),
      actions: [
        IconButton(
          tooltip: semuaTerpilih ? 'Batalkan semua' : 'Pilih semua',
          icon: Icon(semuaTerpilih ? Icons.deselect : Icons.select_all),
          onPressed: _toggleAmbilSemua,
        ),
        IconButton(
          tooltip: 'Hapus terpilih',
          icon: const Icon(Icons.delete_outline),
          onPressed: _idTerpilih.isEmpty ? null : _hapusTerpilih,
        ),
      ],
    );
  }

  Widget _buildPencarianDanFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _cariController,
              onSubmitted: (v) {
                _kataCari = v;
                _muatUlang();
              },
              decoration: InputDecoration(
                hintText: 'Cari nama barang...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterKategori(),
        ],
      ),
    );
  }

  Widget _buildFilterKategori() {
    final aktif = _kategoriDipilih != null;
    return PopupMenuButton<String?>(
      tooltip: 'Filter kategori',
      onSelected: (value) {
        setState(() => _kategoriDipilih = value);
        _muatUlang();
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('Semua kategori')),
        ..._daftarKategori.map((k) => PopupMenuItem<String?>(value: k, child: Text(k))),
      ],
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: aktif ? _biru : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: aktif ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(Icons.filter_list, color: aktif ? Colors.white : Colors.black54),
      ),
    );
  }

  Widget _buildIsiList() {
    if (_loadingAwal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_adaError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat data.'),
            const SizedBox(height: 8),
            TextButton(onPressed: _muatUlang, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (_assets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatUlang,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                _kategoriDipilih != null || _kataCari.isNotEmpty
                    ? 'Tidak ada barang yang cocok.'
                    : 'Belum ada data aset.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _muatUlang,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _assets.length + 1, // +1 untuk indikator "memuat lagi" / akhir data
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _assets.length) {
            return _buildFooterList();
          }
          final a = _assets[index];
          final terpilih = _idTerpilih.contains(a.id);
          return _buildKartuBarang(a, terpilih);
        },
      ),
    );
  }

  Widget _buildFooterList() {
    if (_loadingLagi) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!_masihAdaHalamanBerikutnya) {
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

  Widget _buildKartuBarang(Asset a, bool terpilih) {
    return Container(
      decoration: BoxDecoration(
        color: terpilih ? _biru.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: terpilih ? Border.all(color: _biru, width: 1.4) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _modePilih
            ? Checkbox(
                value: terpilih,
                activeColor: _biru,
                onChanged: (_) {
                  setState(() {
                    if (terpilih) {
                      _idTerpilih.remove(a.id);
                    } else {
                      _idTerpilih.add(a.id);
                    }
                  });
                },
              )
            : const CircleAvatar(
                backgroundColor: _biru,
                child: Icon(Icons.inventory_2_outlined, color: Colors.white),
              ),
        title: Text(a.namaBarang, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${a.kodeAset} • ${a.kategori}'),
        trailing: _modePilih ? null : _StatusBadge(status: a.status),
        onTap: () async {
          if (_modePilih) {
            setState(() {
              if (terpilih) {
                _idTerpilih.remove(a.id);
              } else {
                _idTerpilih.add(a.id);
              }
            });
            return;
          }
          final perluRefresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailBarangScreen(asset: a, isAdmin: _isAdmin),
            ),
          );
          if (perluRefresh == true) _muatUlang();
        },
        onLongPress: _isAdmin && !_modePilih ? () => _masukModePilih(a.id) : null,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _warna.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(color: _warna, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
