import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class DetailBarangScreen extends StatefulWidget {
  final Asset asset;
  final bool isAdmin;
  const DetailBarangScreen({super.key, required this.asset, this.isAdmin = false});

  @override
  State<DetailBarangScreen> createState() => _DetailBarangScreenState();
}

class _DetailBarangScreenState extends State<DetailBarangScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  late TextEditingController _namaController;
  late TextEditingController _kategoriController;
  late TextEditingController _deskripsiController;
  late String _status;

  bool _modeEdit = false;
  bool _menyimpan = false;
  String? _token;

  final List<String> _pilihanStatus = ['tersedia', 'dipinjam', 'rusak'];

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.asset.namaBarang);
    _kategoriController = TextEditingController(text: widget.asset.kategori);
    _deskripsiController = TextEditingController(text: widget.asset.deskripsi ?? '');
    _status = widget.asset.status;
    AuthService.getToken().then((t) {
      if (mounted) setState(() => _token = t);
    });
  }

  Future<void> _simpanPerubahan() async {
    setState(() => _menyimpan = true);
    try {
      await ApiService.updateAsset(
        id: widget.asset.id,
        namaBarang: _namaController.text.trim(),
        kategori: _kategoriController.text.trim(),
        deskripsi: _deskripsiController.text.trim(),
        status: _status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan berhasil disimpan.')),
      );
      setState(() => _modeEdit = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _konfirmasiHapus() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Barang?'),
        content: Text(
          'Barang "${widget.asset.namaBarang}" akan dihapus permanen '
          'beserta seluruh histori lokasinya. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    try {
      await ApiService.hapusAsset(widget.asset.id);
      if (!mounted) return;
      Navigator.pop(context, true); // true = kasih tau layar sebelumnya perlu refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
        title: Text(_modeEdit ? 'Edit Barang' : 'Detail Barang'),
        actions: [
          if (widget.isAdmin && !_modeEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _modeEdit = true),
            ),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _konfirmasiHapus,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: SvgPicture.network(
                  ApiService.getQrCodeUrl(widget.asset.id),
                  headers: ApiService.headersDenganToken(_token),
                  width: 160,
                  height: 160,
                  placeholderBuilder: (context) => const SizedBox(
                    width: 160,
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.asset.kodeAset,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (widget.asset.status == 'dipinjam' && widget.asset.peminjamSaatIni != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC9A2E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFFCC9A2E)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sedang Dipinjam Oleh', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          Text(widget.asset.peminjamSaatIni!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Lokasi terakhir hasil scan (sinkron dengan data di Peta).
            if (widget.asset.lokasiTerakhir != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tombolCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: tombolCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lokasi Terakhir',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          Text(
                            widget.asset.lokasiTerakhir!.lokasiInput,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Builder(builder: (context) {
                            final w = widget.asset.lokasiTerakhir!.scannedAt.toLocal();
                            return Text(
                              'Discan pada ${w.day}/${w.month}/${w.year} '
                              '${w.hour.toString().padLeft(2, '0')}:'
                              '${w.minute.toString().padLeft(2, '0')} WIB',
                              style: const TextStyle(fontSize: 12, color: Colors.black45),
                            );
                          }),
                          if (widget.asset.lokasiTerakhir!.catatan != null &&
                              widget.asset.lokasiTerakhir!.catatan!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.sticky_note_2_outlined, size: 13, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.asset.lokasiTerakhir!.catatan!,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.asset.ruanganAsal != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Posisi awal saat input: ${widget.asset.ruanganAsal}',
                      style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ),
              ],
            ] else if (widget.asset.ruanganAsal != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, color: Colors.orange.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lokasi Terakhir', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          Text(
                            widget.asset.ruanganAsal!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Posisi awal saat input — barang ini belum pernah discan. '
                            'Lokasi akan diperbarui otomatis setelah dipindai lewat menu Scan QR.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Barang ini belum pernah discan dan belum ada ruangan asal yang diisi. '
                  'Lokasi akan muncul setelah barang dipindai lewat menu Scan QR.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],

            const SizedBox(height: 24),

            _buildField('Nama Barang', _namaController, editable: _modeEdit),
            const SizedBox(height: 14),
            _buildField('Kategori', _kategoriController, editable: _modeEdit),
            const SizedBox(height: 14),
            _buildField('Deskripsi', _deskripsiController, editable: _modeEdit, maxLines: 3),
            const SizedBox(height: 14),

            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _modeEdit
                ? Wrap(
                    spacing: 8,
                    children: _pilihanStatus.map((s) {
                      final terpilih = s == _status;
                      return ChoiceChip(
                        label: Text(s),
                        selected: terpilih,
                        selectedColor: tombolCyan.withOpacity(0.25),
                        onSelected: (_) => setState(() => _status = s),
                      );
                    }).toList(),
                  )
                : Chip(label: Text(_status)),

            const SizedBox(height: 32),

            if (_modeEdit)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _menyimpan ? null : _simpanPerubahan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tombolCyan,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _menyimpan
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    required bool editable,
    int maxLines = 1,
  }) {
    if (!editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            controller.text.isEmpty ? '-' : controller.text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
