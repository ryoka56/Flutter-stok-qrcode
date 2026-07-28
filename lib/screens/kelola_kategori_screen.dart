import 'package:flutter/material.dart';
import '../services/api_service.dart';

class KelolaKategoriScreen extends StatefulWidget {
  const KelolaKategoriScreen({super.key});

  @override
  State<KelolaKategoriScreen> createState() => _KelolaKategoriScreenState();
}

class _KelolaKategoriScreenState extends State<KelolaKategoriScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  late Future<List<Map<String, dynamic>>> _futureKategoris;

  @override
  void initState() {
    super.initState();
    _futureKategoris = ApiService.getKategoris();
  }

  void _muatUlang() {
    setState(() => _futureKategoris = ApiService.getKategoris());
  }

  Future<void> _dialogTambah() async {
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

    if (berhasil == true) _muatUlang();
  }

  Future<void> _hapus(int id, String nama) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Kategori "$nama" akan dihapus permanen.'),
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
      await ApiService.hapusKategori(id);
      _muatUlang();
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
        title: const Text('Kelola Kategori'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureKategoris,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final kategoris = snapshot.data ?? [];
          if (kategoris.isEmpty) {
            return const Center(child: Text('Belum ada kategori. Tambahkan dulu.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: kategoris.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final k = kategoris[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.category_outlined, color: tombolCyan),
                  title: Text(k['nama_kategori'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(k['keterangan'] ?? '-'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _hapus(k['id'], k['nama_kategori']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: tombolCyan,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _dialogTambah,
      ),
    );
  }
}
