import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'cetak_qr_screen.dart';

class TambahBarangScreen extends StatefulWidget {
  const TambahBarangScreen({super.key});

  @override
  State<TambahBarangScreen> createState() => _TambahBarangScreenState();
}

class _TambahBarangScreenState extends State<TambahBarangScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();

  static const Color tombolCyan = Color(0xFF29C5E8);

  bool _menyimpan = false;
  Asset? _asetTersimpan;
  List<Asset> _asetBulkTersimpan = []; // hasil kalau jumlah > 1
  int _progresBulk = 0;
  String? _token;

  bool _memuatMasterData = true;
  List<Map<String, dynamic>> _kategoriList = [];
  List<Map<String, dynamic>> _ruanganList = [];
  String? _kategoriTerpilih;
  String? _ruanganTerpilih;
  int _jumlah = 1;

  @override
  void initState() {
    super.initState();
    AuthService.getToken().then((t) {
      if (mounted) setState(() => _token = t);
    });
    _muatMasterData();
  }

  Future<void> _muatMasterData() async {
    setState(() => _memuatMasterData = true);
    try {
      final kategoris = await ApiService.getKategoris();
      final ruangans = await ApiService.getRuangans();
      if (mounted) {
        setState(() {
          _kategoriList = kategoris;
          _ruanganList = ruangans;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data kategori/ruangan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _memuatMasterData = false);
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kategoriTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu.')),
      );
      return;
    }

    setState(() {
      _menyimpan = true;
      _progresBulk = 0;
    });

    final namaDasar = _namaController.text.trim();
    final deskripsi = _deskripsiController.text.trim().isEmpty ? null : _deskripsiController.text.trim();
    final hasil = <Asset>[];

    try {
      for (int i = 1; i <= _jumlah; i++) {
        // Kalau cuma nambah 1, nama barangnya dibiarkan persis seperti yang
        // diketik. Kalau nambah banyak sekaligus, dikasih penanda "#1, #2, ..."
        // di belakang nama supaya tiap unit fisik tetap bisa dibedain,
        // meskipun mereka barang yang identik (merk & jenis sama).
        final nama = _jumlah > 1 ? '$namaDasar #$i' : namaDasar;
        final asset = await ApiService.tambahAsset(
          namaBarang: nama,
          kategori: _kategoriTerpilih!,
          deskripsi: deskripsi,
          ruanganAsal: _ruanganTerpilih,
        );
        hasil.add(asset);
        if (mounted) setState(() => _progresBulk = i);
      }

      if (mounted) {
        setState(() {
          if (_jumlah > 1) {
            _asetBulkTersimpan = hasil;
          } else {
            _asetTersimpan = hasil.first;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      final berhasil = hasil.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(berhasil > 0
              ? '$berhasil dari $_jumlah barang berhasil dibuat sebelum error: $e'
              : e.toString()),
        ),
      );
      // Kalau sebagian sempat berhasil sebelum error, tetap tampilkan hasil
      // parsialnya supaya QR yang sudah terlanjur dibuat gak hilang percuma.
      if (hasil.isNotEmpty && mounted) {
        setState(() => _asetBulkTersimpan = hasil);
      }
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  void _tambahLagi() {
    setState(() {
      _asetTersimpan = null;
      _asetBulkTersimpan = [];
      _progresBulk = 0;
      _namaController.clear();
      _deskripsiController.clear();
      _kategoriTerpilih = null;
      _ruanganTerpilih = null;
      _jumlah = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Tambah Barang'),
      ),
      body: _asetBulkTersimpan.isNotEmpty
          ? _buildHasilBulk()
          : (_asetTersimpan == null ? _buildForm() : _buildHasilQr()),
    );
  }

  Widget _buildForm() {
    if (_memuatMasterData) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'Isi data barang, sistem akan otomatis membuatkan '
              'kode aset unik dan QR-code untuk ditempel di barang.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildField(
              controller: _namaController,
              label: 'Nama Barang',
              wajib: true,
            ),
            const SizedBox(height: 14),

            // Kategori - wajib pilih dari daftar yang sudah dibuat admin
            if (_kategoriList.isEmpty)
              _buildPeringatanKosong(
                'Belum ada kategori. Tambahkan dulu lewat menu "Kelola Kategori".',
              )
            else
              DropdownButtonFormField<String>(
                value: _kategoriTerpilih,
                decoration: _dekorasiDropdown('Kategori'),
                items: _kategoriList
                    .map((k) => DropdownMenuItem<String>(
                          value: k['nama_kategori'],
                          child: Text(k['nama_kategori']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _kategoriTerpilih = v),
                validator: (v) => v == null ? 'Pilih kategori' : null,
              ),
            const SizedBox(height: 14),

            // Ruangan - opsional, tapi tetap wajib pilih dari daftar (bukan ketik manual)
            if (_ruanganList.isEmpty)
              _buildPeringatanKosong(
                'Belum ada ruangan. Tambahkan dulu lewat menu "Kelola Ruangan" (opsional, boleh dilewati).',
              )
            else
              DropdownButtonFormField<String>(
                value: _ruanganTerpilih,
                decoration: _dekorasiDropdown('Ruangan / Rak Asal (opsional)'),
                items: _ruanganList
                    .map((r) => DropdownMenuItem<String>(
                          value: r['nama_ruangan'],
                          child: Text(r['nama_ruangan']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _ruanganTerpilih = v),
              ),
            const SizedBox(height: 14),

            _buildField(
              controller: _deskripsiController,
              label: 'Deskripsi (opsional)',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _buildStepperJumlah(),
            const SizedBox(height: 8),
            if (_jumlah > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Akan dibuat $_jumlah barang sekaligus, masing-masing dengan '
                  'kode aset & QR-code sendiri-sendiri (nama otomatis dikasih "#1", "#2", dst).',
                  style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _menyimpan ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tombolCyan,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _menyimpan
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          if (_jumlah > 1) ...[
                            const SizedBox(width: 12),
                            Text('Menyimpan $_progresBulk dari $_jumlah...',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ],
                      )
                    : Text(
                        _jumlah > 1 ? 'Simpan & Buat $_jumlah QR-Code' : 'Simpan & Buat QR-Code',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperJumlah() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black45),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Jumlah unit (barang identik)', style: TextStyle(fontSize: 13.5, color: Colors.black87)),
          ),
          IconButton(
            onPressed: _jumlah > 1 ? () => setState(() => _jumlah--) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: tombolCyan,
          ),
          SizedBox(
            width: 28,
            child: Text('$_jumlah',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          IconButton(
            onPressed: _jumlah < 50 ? () => setState(() => _jumlah++) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: tombolCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildHasilBulk() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.check_circle, color: Color(0xFF2E9E5B), size: 56),
          const SizedBox(height: 12),
          Text(
            '${_asetBulkTersimpan.length} barang berhasil ditambahkan!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tiap barang sudah punya kode aset & QR-code sendiri.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: _asetBulkTersimpan.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = _asetBulkTersimpan[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.qr_code_2_rounded, color: tombolCyan),
                    title: Text(a.namaBarang, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text(a.kodeAset, style: const TextStyle(fontSize: 11.5)),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CetakQrScreen(semuaAsset: _asetBulkTersimpan)),
              ),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Cetak Semua QR Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: tombolCyan,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _tambahLagi,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Tambah Barang Lain', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeringatanKosong(String pesan) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pesan, style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dekorasiDropdown(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool wajib = false,
    int maxLines = 1,
  }) {
    return TextFormField(
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
      validator: wajib
          ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null
          : null,
    );
  }

  Widget _buildHasilQr() {
    final asset = _asetTersimpan!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.check_circle, color: Color(0xFF2E9E5B), size: 56),
          const SizedBox(height: 12),
          Text(
            asset.namaBarang,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Kode Aset: ${asset.kodeAset}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: SvgPicture.network(
              ApiService.getQrCodeUrl(asset.id),
              headers: ApiService.headersDenganToken(_token),
              width: 220,
              height: 220,
              placeholderBuilder: (context) => const SizedBox(
                width: 220,
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Screenshot atau cetak QR-code ini, lalu tempel pada barang fisik.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _tambahLagi,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Tambah Barang Lain',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: tombolCyan,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Selesai',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
