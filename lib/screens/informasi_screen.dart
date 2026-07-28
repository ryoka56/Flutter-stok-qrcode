import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/refrescable.dart';

class InformasiScreen extends StatefulWidget {
  const InformasiScreen({super.key});

  @override
  State<InformasiScreen> createState() => _InformasiScreenState();
}

class _InformasiScreenState extends State<InformasiScreen> implements Refrescable {
  static const Color tombolCyan = Color(0xFF29C5E8);

  late Future<List<Asset>> _futureAssets;
  bool _pencarianAktif = false;
  final _cariController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _futureAssets = ApiService.getAllAssets();
  }

  @override
  Future<void> refreshDiam() async {
    // Ambil data baru dulu di background, baru ganti _futureAssets kalau
    // sudah selesai -> FutureBuilder tidak sempat nampilin spinner karena
    // Future yang lama masih terpasang sampai data baru beneran siap.
    try {
      final data = await ApiService.getAllAssets(cari: _cariController.text.isEmpty ? null : _cariController.text);
      if (mounted) setState(() => _futureAssets = Future.value(data));
    } catch (_) {
      // gagal diam-diam, data lama tetap tampil
    }
  }

  void _muatUlang({String? cari}) {
    setState(() => _futureAssets = ApiService.getAllAssets(cari: cari));
  }

  Widget _kotakCari() {
    if (_pencarianAktif) {
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
                  onSubmitted: (v) => _muatUlang(cari: v),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Cari barang...',
                    hintStyle: TextStyle(fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _cariController.clear();
                  setState(() => _pencarianAktif = false);
                  _muatUlang();
                },
                child: const Icon(Icons.close, size: 16, color: Colors.black45),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _pencarianAktif = true),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
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
                  decoration:
                      BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Dashboard Informasi',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                _kotakCari(),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Asset>>(
              future: _futureAssets,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final assets = snapshot.data ?? [];
                if (assets.isEmpty) {
                  return const Center(child: Text('Belum ada data barang.'));
                }
                return ListView.separated(
                  itemCount: assets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = assets[index];
                    return Container(
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tombolCyan.withOpacity(0.15),
                          child: const Icon(Icons.inventory_2_outlined, color: tombolCyan, size: 20),
                        ),
                        title: Text(a.namaBarang, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${a.kodeAset} • ${a.kategori}'),
                        trailing: _StatusBadge(status: a.status),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _warna.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: _warna, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
