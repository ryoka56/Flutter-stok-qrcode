import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/asset.dart';

/// Layar cetak QR-code massal.
///
/// - Bisa pilih barang satu-satu (checklist) atau "Pilih Semua" buat cetak
///   sekaligus dalam satu proses.
/// - Ukuran QR-code bisa diatur bebas lewat slider (kecil ke besar), preview
///   PDF live ke-update otomatis tiap ukuran/pilihan berubah.
/// - Semua QR disusun otomatis dalam grid di atas kertas A4; kalau barangnya
///   banyak, otomatis lanjut ke halaman berikutnya (tidak dipotong/hilang).
/// - Tombol cetak/simpan memakai dialog print bawaan browser (jalan di Web).
class CetakQrScreen extends StatefulWidget {
  final List<Asset> semuaAsset;
  final Asset? assetAwal; // kalau dibuka dari 1 baris tertentu, langsung terpilih sendirian

  const CetakQrScreen({super.key, required this.semuaAsset, this.assetAwal});

  @override
  State<CetakQrScreen> createState() => _CetakQrScreenState();
}

class _CetakQrScreenState extends State<CetakQrScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);
  static const Color biruTua = Color(0xFF16213E);

  late Set<int> _terpilih;
  double _ukuranMm = 35;
  String _pencarian = '';
  String? _ruanganFilter;

  @override
  void initState() {
    super.initState();
    _terpilih = widget.assetAwal != null
        ? {widget.assetAwal!.id}
        : widget.semuaAsset.map((a) => a.id).toSet();
  }

  // "Ruangan saat ini" = lokasi hasil scan terakhir kalau ada, fallback ke
  // ruangan asal (sama persis logika yang dipakai di Kelola Barang), biar
  // filter di sini konsisten sama yang ditampilkan di sana.
  String? _ruanganSaatIni(Asset a) => a.lokasiTerakhir?.lokasiInput ?? a.ruanganAsal;

  List<String> get _daftarRuangan {
    final set = <String>{};
    for (final a in widget.semuaAsset) {
      final r = _ruanganSaatIni(a);
      if (r != null && r.isNotEmpty) set.add(r);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Asset> get _assetTersaring => widget.semuaAsset
      .where((a) =>
          (a.namaBarang.toLowerCase().contains(_pencarian) ||
              a.kodeAset.toLowerCase().contains(_pencarian) ||
              a.kategori.toLowerCase().contains(_pencarian)) &&
          (_ruanganFilter == null || _ruanganSaatIni(a) == _ruanganFilter))
      .toList();

  List<Asset> get _assetDicetak =>
      widget.semuaAsset.where((a) => _terpilih.contains(a.id)).toList();

  Future<Uint8List> _buatPdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final sisiPt = _ukuranMm * PdfPageFormat.mm;
    final asetDicetak = _assetDicetak;

    // Font keterangan ikut mengecil/membesar proporsional sama ukuran QR,
    // basis skala di ukuran 35mm (ukuran default). Dikasih batas bawah/atas
    // (clamp) biar di ukuran ekstrem kecil (5mm) teksnya masih kebaca dikit,
    // dan di ukuran ekstrem besar (80mm) gak jadi kegedean gak proporsional.
    final skala = _ukuranMm / 35;
    double f(double basis, double min, double max) => (basis * skala).clamp(min, max);
    final fontNama = f(9, 4, 13);
    final fontKategori = f(7.5, 3.5, 10.5);
    final fontKode = f(7, 3.5, 10);
    final jarakVertikal = f(6, 2, 8);
    final jarakKecil = f(2, 1, 3);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 20, marginRight: 20, marginTop: 20, marginBottom: 20,
        ),
        build: (context) => [
          pw.Wrap(
            spacing: 14,
            runSpacing: 18,
            children: asetDicetak.map((a) {
              return pw.Container(
                width: sisiPt + 16,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: a.kodeAset,
                      width: sisiPt,
                      height: sisiPt,
                    ),
                    pw.SizedBox(height: jarakVertikal),
                    pw.Text(
                      a.namaBarang,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: fontNama, fontWeight: pw.FontWeight.bold),
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                      softWrap: true,
                    ),
                    pw.SizedBox(height: jarakKecil),
                    pw.Text(
                      a.kategori,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: fontKategori, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: jarakKecil),
                    pw.Text(
                      a.kodeAset,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: fontKode, color: PdfColors.grey600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Column(
        children: [
          _buildHeader(),
          _buildKontrol(),
          Expanded(
            child: _assetDicetak.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Pilih minimal 1 barang di bawah untuk melihat preview cetak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black45),
                      ),
                    ),
                  )
                : PdfPreview(
                    key: ValueKey('${_terpilih.length}-$_ukuranMm'),
                    build: (format) => _buatPdf(format),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    pdfFileName: 'qr-aset-gudang-komdigi.pdf',
                    loadingWidget: const Center(child: CircularProgressIndicator()),
                  ),
          ),
          _buildDaftarPilih(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Cetak QR Code (${_terpilih.length} dipilih)',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildKontrol() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded, size: 16, color: Colors.black45),
              const SizedBox(width: 6),
              Text(
                'Ukuran QR-code: ${_ukuranMm.toStringAsFixed(0)} mm '
                '(${(_ukuranMm / 10).toStringAsFixed(1)} cm)',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: biruTua),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  final idTersaring = _assetTersaring.map((a) => a.id).toSet();
                  final semuaTerpilih = idTersaring.isNotEmpty && idTersaring.every(_terpilih.contains);
                  if (semuaTerpilih) {
                    _terpilih.removeAll(idTersaring);
                  } else {
                    _terpilih.addAll(idTersaring);
                  }
                }),
                icon: Icon(
                  (_assetTersaring.isNotEmpty &&
                          _assetTersaring.map((a) => a.id).every(_terpilih.contains))
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                  size: 16,
                ),
                label: Text(
                  (_assetTersaring.isNotEmpty &&
                          _assetTersaring.map((a) => a.id).every(_terpilih.contains))
                      ? (_ruanganFilter != null || _pencarian.isNotEmpty ? 'Batal (Hasil Filter)' : 'Batal Semua')
                      : (_ruanganFilter != null || _pencarian.isNotEmpty ? 'Pilih Semua (Hasil Filter)' : 'Pilih Semua'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(foregroundColor: tombolCyan),
              ),
            ],
          ),
          Slider(
            value: _ukuranMm,
            min: 5,
            max: 80,
            divisions: 75, // 1mm per langkah biar presisi buat ukuran kecil kayak 5-10mm
            activeColor: tombolCyan,
            label: '${_ukuranMm.toStringAsFixed(0)} mm (${(_ukuranMm / 10).toStringAsFixed(1)} cm)',
            onChanged: (v) => setState(() => _ukuranMm = v),
          ),
          // Tombol pintas ukuran umum, biar gak perlu geser slider pelan-pelan
          // buat dapet angka presisi kayak 5mm/10mm.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [5, 10, 15, 20, 25, 30, 40, 50, 80].map((ukuran) {
              final aktif = _ukuranMm.round() == ukuran;
              return ChoiceChip(
                label: Text('${ukuran}mm', style: const TextStyle(fontSize: 11.5)),
                selected: aktif,
                onSelected: (_) => setState(() => _ukuranMm = ukuran.toDouble()),
                selectedColor: tombolCyan,
                labelStyle: TextStyle(color: aktif ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                backgroundColor: const Color(0xFFF0F3F7),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          if (_ukuranMm < 15)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ukuran di bawah 15mm mungkin sulit discan tergantung kualitas printer & kamera HP.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tombolFilterRuangan() {
    final aktif = _ruanganFilter != null;
    return PopupMenuButton<String?>(
      tooltip: 'Filter berdasarkan ruangan',
      onSelected: (v) => setState(() => _ruanganFilter = v),
      itemBuilder: (context) => [
        const PopupMenuItem<String?>(value: null, child: Text('Semua ruangan')),
        ..._daftarRuangan.map((r) => PopupMenuItem<String?>(value: r, child: Text(r))),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: aktif ? biruTua : const Color(0xFFF3F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_outlined, size: 16, color: aktif ? Colors.white : Colors.black54),
            if (aktif) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(
                  _ruanganFilter!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDaftarPilih() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Cari barang untuk dipilih...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF3F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _pencarian = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                _tombolFilterRuangan(),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _assetTersaring.length,
              itemBuilder: (context, i) {
                final a = _assetTersaring[i];
                final dipilih = _terpilih.contains(a.id);
                return CheckboxListTile(
                  dense: true,
                  value: dipilih,
                  activeColor: tombolCyan,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(a.namaBarang, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${a.kodeAset} • ${a.kategori}', style: const TextStyle(fontSize: 11)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _terpilih.add(a.id);
                    } else {
                      _terpilih.remove(a.id);
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
