class Asset {
  final int id;
  final String kodeAset;
  final String namaBarang;
  final String kategori;
  final String? deskripsi;
  final String? ruanganAsal;
  final String status;
  final LokasiTerakhir? lokasiTerakhir;
  final String? peminjamSaatIni; // cuma terisi kalau status == 'dipinjam'

  Asset({
    required this.id,
    required this.kodeAset,
    required this.namaBarang,
    required this.kategori,
    this.deskripsi,
    this.ruanganAsal,
    required this.status,
    this.lokasiTerakhir,
    this.peminjamSaatIni,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'],
      kodeAset: json['kode_aset'],
      namaBarang: json['nama_barang'],
      kategori: json['kategori'],
      deskripsi: json['deskripsi'],
      ruanganAsal: json['ruangan_asal'],
      status: json['status'] ?? 'tersedia',
      lokasiTerakhir: json['lokasi_terakhir'] != null
          ? LokasiTerakhir.fromJson(json['lokasi_terakhir'])
          : null,
      peminjamSaatIni: json['peminjam_saat_ini'],
    );
  }
}

/// Hasil GET /assets/rekap - statistik yang sudah dihitung backend
/// (GROUP BY/COUNT), bukan dihitung manual di app dari ribuan data mentah.
class RekapAset {
  final Map<String, int> perStatus;
  final Map<String, int> perKategori;
  final Map<String, int> perRuangan;
  final int total;

  RekapAset({required this.perStatus, required this.perKategori, required this.perRuangan, required this.total});

  factory RekapAset.fromJson(Map<String, dynamic> json) {
    Map<String, int> keMap(List data, String kunci) {
      final hasil = <String, int>{};
      for (final item in data) {
        final key = item[kunci]?.toString() ?? '-';
        hasil[key] = (item['jumlah'] as num).toInt();
      }
      return hasil;
    }

    return RekapAset(
      perStatus: keMap(json['per_status'] ?? [], 'status'),
      perKategori: keMap(json['per_kategori'] ?? [], 'kategori'),
      perRuangan: keMap(json['per_ruangan'] ?? [], 'ruangan'),
      total: json['total'] ?? 0,
    );
  }
}

/// Menampung hasil paginasi dari Laravel (paginate()), supaya HomeScreen tahu
/// masih ada halaman berikutnya atau tidak (dipakai buat infinite-scroll).
class AssetPage {
  final List<Asset> data;
  final int currentPage;
  final int lastPage;
  final int total;

  AssetPage({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get masihAdaHalamanBerikutnya => currentPage < lastPage;

  factory AssetPage.fromJson(Map<String, dynamic> json) {
    final List list = json['data'] ?? [];
    return AssetPage(
      data: list.map((e) => Asset.fromJson(e)).toList(),
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      total: json['total'] ?? list.length,
    );
  }
}

/// Info lokasi terakhir barang berdasarkan histori scan paling baru.
/// Ini yang bikin data di Detail Barang & Peta selalu sinkron,
/// karena sama-sama ambil dari sumber yang sama (tabel scan_logs).
class LokasiTerakhir {
  final String lokasiInput;
  final DateTime scannedAt;
  final String? catatan;

  LokasiTerakhir({required this.lokasiInput, required this.scannedAt, this.catatan});

  factory LokasiTerakhir.fromJson(Map<String, dynamic> json) {
    return LokasiTerakhir(
      lokasiInput: json['lokasi_input'] ?? '-',
      scannedAt: DateTime.parse(json['scanned_at']),
      catatan: json['catatan'],
    );
  }
}
