import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../services/api_service.dart';

/// Barang yang sudah dihapus (soft delete) masih bisa dipulihkan dari sini,
/// jaga-jaga kalau admin salah pencet hapus (apalagi sekarang ada fitur
/// hapus banyak sekaligus, resikonya lebih besar kalau salah pilih item).
class SampahScreen extends StatefulWidget {
  const SampahScreen({super.key});

  @override
  State<SampahScreen> createState() => _SampahScreenState();
}

class _SampahScreenState extends State<SampahScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  bool _loading = true;
  bool _error = false;
  List<Asset> _sampah = [];
  bool _adaPerubahan = false; // dikembalikan ke layar sebelumnya via Navigator.pop

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final hasil = await ApiService.getTrash();
      if (mounted) setState(() => _sampah = hasil.data);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pulihkan(Asset a) async {
    try {
      await ApiService.restoreAsset(a.id);
      _adaPerubahan = true;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('"${a.namaBarang}" berhasil dipulihkan')));
      }
      _muat();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memulihkan: $e')));
    }
  }

  Future<void> _hapusPermanen(Asset a) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus permanen?'),
        content: Text(
            '"${a.namaBarang}" akan dihapus SELAMANYA dan tidak bisa dipulihkan lagi. Yakin lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB03A3A)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    try {
      await ApiService.forceDeleteAsset(a.id);
      _adaPerubahan = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${a.namaBarang}" dihapus permanen')));
      }
      _muat();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _adaPerubahan);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: tombolCyan,
          foregroundColor: Colors.white,
          title: const Text('Sampah'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _adaPerubahan),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat data sampah.'),
            const SizedBox(height: 8),
            TextButton(onPressed: _muat, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (_sampah.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Sampah kosong', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sampah.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final a = _sampah[i];
          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration:
                      BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.red, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.namaBarang, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('${a.kodeAset} • ${a.kategori}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Pulihkan',
                  icon: const Icon(Icons.restore, color: tombolCyan),
                  onPressed: () => _pulihkan(a),
                ),
                IconButton(
                  tooltip: 'Hapus permanen',
                  icon: const Icon(Icons.delete_forever, color: Color(0xFFB03A3A)),
                  onPressed: () => _hapusPermanen(a),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
