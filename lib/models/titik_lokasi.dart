class TitikLokasi {
  final int assetId;
  final String namaBarang;
  final String kodeAset;
  final String kategori;
  final String lokasiInput;
  final String? namaPetugas;
  final String? namaPeminjam;
  final String? statusSaatItu;
  final String? statusSebelum;
  final bool isPeminjaman;
  final bool isPengembalian;
  final double latitude;
  final double longitude;
  final DateTime scannedAt;
  final String? catatan;

  TitikLokasi({
    required this.assetId,
    required this.namaBarang,
    required this.kodeAset,
    required this.kategori,
    required this.lokasiInput,
    this.namaPetugas,
    this.namaPeminjam,
    this.statusSaatItu,
    this.statusSebelum,
    this.isPeminjaman = false,
    this.isPengembalian = false,
    required this.latitude,
    required this.longitude,
    required this.scannedAt,
    this.catatan,
  });

  /// Label singkat jenis aktivitas ini, dipakai buat tampilan riwayat.
  /// - "Dipinjam"      : status berubah (tersedia/rusak) -> dipinjam
  /// - "Dikembalikan"  : status berubah dipinjam -> (tersedia/rusak)
  /// - "Diperbarui"    : perubahan lain (mis. tersedia <-> rusak, atau
  ///                      cuma update lokasi tanpa ganti status)
  String get labelJenis {
    if (isPeminjaman) return 'Dipinjam';
    if (isPengembalian) return 'Dikembalikan';
    return 'Diperbarui';
  }

  factory TitikLokasi.fromJson(Map<String, dynamic> json) {
    final asset = json['asset'] ?? {};
    return TitikLokasi(
      assetId: json['asset_id'],
      namaBarang: asset['nama_barang'] ?? '-',
      kodeAset: asset['kode_aset'] ?? '-',
      kategori: asset['kategori'] ?? '-',
      lokasiInput: json['lokasi_input'] ?? '-',
      namaPetugas: json['nama_petugas'],
      namaPeminjam: json['nama_peminjam'],
      statusSaatItu: json['status_saat_itu'],
      statusSebelum: json['status_sebelum'],
      isPeminjaman: json['is_peminjaman'] == true || json['is_peminjaman'] == 1,
      isPengembalian: json['is_pengembalian'] == true || json['is_pengembalian'] == 1,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      scannedAt: DateTime.parse(json['scanned_at']),
      catatan: json['catatan'],
    );
  }
}
