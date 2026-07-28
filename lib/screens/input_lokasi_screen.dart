import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';

class InputLokasiScreen extends StatefulWidget {
  final Asset asset;
  const InputLokasiScreen({super.key, required this.asset});

  @override
  State<InputLokasiScreen> createState() => _InputLokasiScreenState();
}

class _InputLokasiScreenState extends State<InputLokasiScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  final _formKey = GlobalKey<FormState>();
  final _catatanController = TextEditingController();

  final List<String> _pilihanStatus = ['tersedia', 'dipinjam', 'rusak'];
  late String _status;
  String? _namaPetugasLogin;

  bool _memuatRuangan = true;
  List<Map<String, dynamic>> _ruanganList = [];
  String? _ruanganTerpilih;

  // Nama peminjam sekarang dipilih dari daftar Pegawai (dikelola admin lewat
  // Pengaturan > Kelola Pegawai), bukan diketik bebas - biar konsisten &
  // gak ada typo/beda ejaan nama orang yang sama antar scan.
  bool _memuatPegawai = true;
  List<Map<String, dynamic>> _pegawaiList = [];
  String? _namaPeminjamTerpilih;

  Position? _posisi;
  bool _mengambilLokasi = true;
  bool _menyimpan = false;
  String? _errorLokasi;

  @override
  void initState() {
    super.initState();
    _status = widget.asset.status;
    _ambilPosisi();
    _muatNamaPetugas();
    _muatRuangan();
    _muatPegawai();
  }

  Future<void> _muatPegawai() async {
    setState(() => _memuatPegawai = true);
    try {
      final pegawais = await ApiService.getPegawais();
      if (mounted) setState(() => _pegawaiList = pegawais);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar pegawai: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _memuatPegawai = false);
    }
  }

  Future<void> _muatNamaPetugas() async {
    final nama = await AuthService.getNama();
    if (mounted) setState(() => _namaPetugasLogin = nama);
  }

  Future<void> _muatRuangan() async {
    setState(() => _memuatRuangan = true);
    try {
      final ruangans = await ApiService.getRuangans();
      if (mounted) setState(() => _ruanganList = ruangans);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar ruangan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _memuatRuangan = false);
    }
  }

  Future<void> _ambilPosisi() async {
    setState(() {
      _mengambilLokasi = true;
      _errorLokasi = null;
    });
    try {
      final pos = await LocationService.ambilLokasiSaatIni();
      setState(() => _posisi = pos);
    } catch (e) {
      setState(() => _errorLokasi = e.toString());
    } finally {
      setState(() => _mengambilLokasi = false);
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ruanganTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih ruangan tujuan terlebih dahulu.')),
      );
      return;
    }
    if (_status == 'dipinjam' && (_namaPeminjamTerpilih == null || _namaPeminjamTerpilih!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih nama peminjam terlebih dahulu.')),
      );
      return;
    }
    if (_posisi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat GPS belum tersedia.')),
      );
      return;
    }

    setState(() => _menyimpan = true);
    try {
      await ApiService.kirimScanLog(
        kodeAset: widget.asset.kodeAset,
        lokasiInput: _ruanganTerpilih!,
        latitude: _posisi!.latitude,
        longitude: _posisi!.longitude,
        namaPeminjam: _namaPeminjamTerpilih,
        catatan: _catatanController.text.trim().isEmpty
            ? null
            : _catatanController.text.trim(),
        status: _status,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peminjaman barang berhasil dicatat.')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return Scaffold(
      appBar: AppBar(title: const Text('Input Peminjaman Barang')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                child: ListTile(
                  title: Text(asset.namaBarang),
                  subtitle: Text('${asset.kodeAset} • ${asset.kategori}'),
                  leading: const Icon(Icons.inventory_2),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tombolCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge, size: 18, color: tombolCyan),
                    const SizedBox(width: 8),
                    Text(
                      'Dicatat oleh petugas: ${_namaPetugasLogin ?? '...'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Nama peminjam - pilih dari daftar Pegawai (dikelola admin lewat
              // Pengaturan > Kelola Pegawai), wajib cuma pas status "dipinjam".
              if (_memuatPegawai)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_pegawaiList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Belum ada data pegawai. Minta admin menambahkan pegawai '
                    'lewat menu "Kelola Pegawai" terlebih dahulu.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _namaPeminjamTerpilih,
                  decoration: InputDecoration(
                    labelText: _status == 'dipinjam'
                        ? 'Nama Peminjam (siapa yang mengambil barang)'
                        : 'Dikembalikan/diperiksa oleh (opsional)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                    helperText: _status != 'dipinjam'
                        ? 'Boleh dikosongkan karena barang tidak sedang dipinjamkan'
                        : null,
                  ),
                  items: _pegawaiList
                      .map((p) => DropdownMenuItem<String>(
                            value: p['nama_pegawai'],
                            child: Text(
                              p['jabatan'] != null && p['jabatan'].toString().isNotEmpty
                                  ? '${p['nama_pegawai']} (${p['jabatan']})'
                                  : p['nama_pegawai'],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _namaPeminjamTerpilih = v),
                  validator: (v) => (_status == 'dipinjam' && (v == null || v.isEmpty))
                      ? 'Wajib dipilih waktu meminjamkan barang'
                      : null,
                ),
              const SizedBox(height: 12),

              // Lokasi tujuan - wajib pilih dari daftar ruangan (sinkron dengan Kelola Ruangan)
              if (_memuatRuangan)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_ruanganList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Belum ada data ruangan. Minta admin menambahkan ruangan '
                    'lewat menu "Kelola Ruangan" terlebih dahulu.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _ruanganTerpilih,
                  decoration: const InputDecoration(
                    labelText: 'Ruangan Tujuan',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  items: _ruanganList
                      .map((r) => DropdownMenuItem<String>(
                            value: r['nama_ruangan'],
                            child: Text(r['nama_ruangan']),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _ruanganTerpilih = v),
                  validator: (v) => v == null ? 'Pilih ruangan tujuan' : null,
                ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _catatanController,
                decoration: const InputDecoration(
                  labelText: 'Catatan tambahan (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Status Barang', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
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
              ),
              const SizedBox(height: 16),
              _buildStatusLokasi(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _menyimpan ? null : _simpan,
                icon: _menyimpan
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_menyimpan ? 'Menyimpan...' : 'Simpan Peminjaman'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLokasi() {
    if (_mengambilLokasi) {
      return const Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Mengambil koordinat GPS...'),
        ],
      );
    }
    if (_errorLokasi != null) {
      return Row(
        children: [
          Expanded(child: Text(_errorLokasi!, style: const TextStyle(color: Colors.red))),
          TextButton(onPressed: _ambilPosisi, child: const Text('Coba lagi')),
        ],
      );
    }
    if (_posisi != null) {
      return Text(
        'Koordinat: ${_posisi!.latitude.toStringAsFixed(6)}, '
        '${_posisi!.longitude.toStringAsFixed(6)}',
        style: const TextStyle(color: Colors.green),
      );
    }
    return const SizedBox.shrink();
  }
}
