import 'package:flutter/material.dart';
import '../services/api_service.dart';

class KelolaRuanganScreen extends StatefulWidget {
  const KelolaRuanganScreen({super.key});

  @override
  State<KelolaRuanganScreen> createState() => _KelolaRuanganScreenState();
}

class _KelolaRuanganScreenState extends State<KelolaRuanganScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  bool _loading = true;
  List<Map<String, dynamic>> _ruangans = [];
  Map<String, int> _jumlahBarangPerRuangan = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final ruangans = await ApiService.getRuangans();
      // Rekap dihitung backend (GROUP BY), gak perlu tarik semua barang ke
      // app terus dihitung manual - jauh lebih ringan begitu data membesar.
      final rekap = await ApiService.getRekap();

      if (mounted) {
        setState(() {
          _ruangans = ruangans;
          _jumlahBarangPerRuangan = rekap.perRuangan;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dialogTambah() async {
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
                  lokasiGedung: lokasiController.text.trim().isEmpty
                      ? null : lokasiController.text.trim(),
                  keterangan: keteranganController.text.trim().isEmpty
                      ? null : keteranganController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (berhasil == true) _muat();
  }

  Future<void> _hapus(int id, String nama) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Ruangan?'),
        content: Text('Ruangan "$nama" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    try {
      await ApiService.hapusRuangan(id);
      _muat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Kelola Ruangan'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _muat)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ruangans.isEmpty
              ? const Center(child: Text('Belum ada ruangan. Tambahkan dulu.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ruangans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = _ruangans[index];
                    final jumlahBarang = _jumlahBarangPerRuangan[r['nama_ruangan']] ?? 0;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room_outlined, color: tombolCyan),
                        title: Text(r['nama_ruangan'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(r['lokasi_gedung'] ?? '-'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: tombolCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$jumlahBarang barang',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _hapus(r['id'], r['nama_ruangan']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: tombolCyan,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Ruangan', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _dialogTambah,
      ),
    );
  }
}
