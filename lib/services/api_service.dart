import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset.dart';
import '../models/titik_lokasi.dart';
import 'auth_service.dart';

class ApiService {
  // GANTI sesuai alamat server Laravel-mu (URL Railway untuk production)
  static const String baseUrl = 'https://manajemen-stok-qrcode-production.up.railway.app/api';

  // Header standar + token login (dipakai di semua request yang butuh autentikasi)
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String getQrCodeUrl(int assetId) {
    return '$baseUrl/assets/$assetId/qrcode';
  }

  // Header yang bisa dipakai widget lain (mis. SvgPicture.network)
  // yang butuh nyertain token login manual saat fetch gambar.
  static Future<Map<String, String>> getAuthHeaders() => _headers();

  // Versi sinkron, dipakai saat token sudah diambil duluan di initState
  // (misal disimpan di variabel _token) - supaya bisa langsung dipakai
  // di widget seperti SvgPicture.network yang butuh Map biasa, bukan Future.
  static Map<String, String> headersDenganToken(String? token) {
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }


  static Future<Asset> tambahAsset({
    required String namaBarang,
    required String kategori,
    String? deskripsi,
    String? ruanganAsal,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/assets'),
      headers: await _headers(),
      body: jsonEncode({
        'nama_barang': namaBarang,
        'kategori': kategori,
        'deskripsi': deskripsi,
        'ruangan_asal': ruanganAsal,
      }),
    );

    if (res.statusCode == 201) {
      return Asset.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Gagal menambah barang: ${res.body}');
    }
  }

  // Ambil daftar aset dengan dukungan paginasi (infinite-scroll) & filter kategori.
  // Dipakai HomeScreen supaya data ribuan barang tidak ditarik sekaligus.
  static Future<AssetPage> getAssets({
    String? cari,
    String? kategori,
    String? ruangan,
    int page = 1,
    int perPage = 15,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (cari != null && cari.isNotEmpty) params['cari'] = cari;
    if (kategori != null && kategori.isNotEmpty) params['kategori'] = kategori;
    if (ruangan != null && ruangan.isNotEmpty) params['ruangan'] = ruangan;

    final uri = Uri.parse('$baseUrl/assets').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return AssetPage.fromJson(body);
    } else {
      throw Exception('Gagal mengambil data aset');
    }
  }

  // Ambil SEMUA aset (loop tiap halaman di belakang layar) - dipakai layar
  // rekap/statistik (Tinjauan, Pengaturan, Kelola Ruangan, Informasi) yang
  // butuh hitung total per kategori/ruangan, bukan cuma satu halaman.
  // Untuk daftar yang ditampilkan ke user (List Barang), pakai getAssets() biasa.
  static Future<List<Asset>> getAllAssets({String? cari, String? kategori, String? ruangan}) async {
    final semua = <Asset>[];
    int page = 1;
    while (true) {
      final hasil = await getAssets(cari: cari, kategori: kategori, ruangan: ruangan, page: page, perPage: 100);
      semua.addAll(hasil.data);
      if (!hasil.masihAdaHalamanBerikutnya) break;
      page++;
    }
    return semua;
  }

  // GET /assets/rekap - statistik dihitung backend (GROUP BY), bukan dihitung
  // manual di app dari ribuan data mentah.
  static Future<RekapAset> getRekap() async {
    final res = await http.get(Uri.parse('$baseUrl/assets/rekap'), headers: await _headers());
    if (res.statusCode == 200) {
      return RekapAset.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal mengambil rekap statistik');
  }

  // GET /assets/trash - daftar barang yang sudah dihapus (soft delete), admin only
  static Future<AssetPage> getTrash({int page = 1}) async {
    final uri = Uri.parse('$baseUrl/assets/trash').replace(queryParameters: {'page': page.toString()});
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      return AssetPage.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal mengambil data sampah');
  }

  // POST /assets/{id}/restore - pulihkan barang yang sudah dihapus
  static Future<void> restoreAsset(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/assets/$id/restore'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Gagal memulihkan barang');
  }

  // DELETE /assets/{id}/force - hapus PERMANEN, gak bisa direstore lagi
  static Future<void> forceDeleteAsset(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/assets/$id/force'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Gagal menghapus permanen');
  }

  // POST /assets/{id}/foto - upload/ganti foto di slot 1/2/3 (multipart)
  static Future<Asset> uploadFotoBarang({
    required int assetId,
    required int slot,
    required List<int> bytes,
    required String namaFile,
  }) async {
    final token = await AuthService.getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/assets/$assetId/foto'))
      ..headers['Accept'] = 'application/json'
      ..fields['slot'] = slot.toString()
      ..files.add(http.MultipartFile.fromBytes('foto', bytes, filename: namaFile));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return Asset.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal upload foto: ${res.body}');
  }

  // DELETE /assets/{id}/foto/{slot}
  static Future<Asset> hapusFotoBarang({required int assetId, required int slot}) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/assets/$assetId/foto/$slot'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return Asset.fromJson(jsonDecode(res.body));
    }
    throw Exception('Gagal menghapus foto: ${res.body}');
  }

  // Hapus banyak barang sekaligus (dipakai fitur pilih & hapus massal)
  static Future<int> hapusAssetBanyak(List<int> ids) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/assets/bulk'),
      headers: await _headers(),
      body: jsonEncode({'ids': ids}),
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['jumlah_dihapus'] ?? ids.length;
    } else {
      throw Exception('Gagal menghapus barang terpilih: ${res.body}');
    }
  }

  static Future<Asset> getAssetByKode(String kodeAset) async {
    final res = await http.get(
      Uri.parse('$baseUrl/assets/scan/$kodeAset'),
      headers: await _headers(),
    );

    if (res.statusCode == 200) {
      return Asset.fromJson(jsonDecode(res.body));
    } else if (res.statusCode == 404) {
      throw Exception('Kode aset tidak ditemukan di sistem');
    } else {
      throw Exception('Gagal mengambil detail aset');
    }
  }

  static Future<Asset> updateAsset({
    required int id,
    required String namaBarang,
    required String kategori,
    String? deskripsi,
    String? status,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/assets/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'nama_barang': namaBarang,
        'kategori': kategori,
        'deskripsi': deskripsi,
        'status': status,
      }),
    );

    if (res.statusCode == 200) {
      return Asset.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Gagal mengubah data barang: ${res.body}');
    }
  }

  static Future<void> hapusAsset(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/assets/$id'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus barang: ${res.body}');
    }
  }

  static Future<List<TitikLokasi>> getRiwayat({int? assetId, int? userId, bool hariIni = false}) async {
    final params = <String, String>{};
    if (assetId != null) params['asset_id'] = assetId.toString();
    if (userId != null) params['user_id'] = userId.toString();
    if (hariIni) params['hari_ini'] = '1';

    final uri = Uri.parse('$baseUrl/scan-logs').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body['data'];
      return data.map((e) => TitikLokasi.fromJson(e)).toList();
    } else {
      throw Exception('Gagal mengambil riwayat');
    }
  }

  static Future<List<TitikLokasi>> getPetaLokasi() async {
    final res = await http.get(
      Uri.parse('$baseUrl/scan-logs/peta'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => TitikLokasi.fromJson(e)).toList();
    } else {
      throw Exception('Gagal mengambil data peta');
    }
  }

  // nama petugas TIDAK perlu dikirim lagi - otomatis diambil server dari akun yang login
  static Future<void> kirimScanLog({
    required String kodeAset,
    required String lokasiInput,
    required double latitude,
    required double longitude,
    String? namaPeminjam,
    String? catatan,
    String? status,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/scan-logs'),
      headers: await _headers(),
      body: jsonEncode({
        'kode_aset': kodeAset,
        'lokasi_input': lokasiInput,
        'latitude': latitude,
        'longitude': longitude,
        'nama_peminjam': (namaPeminjam == null || namaPeminjam.isEmpty) ? null : namaPeminjam,
        'catatan': catatan,
        'status': status,
      }),
    );

    if (res.statusCode != 201) {
      String pesan = 'Gagal menyimpan hasil scan.';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] != null) {
          pesan = body['message'].toString();
        } else if (body is Map && body['errors'] != null) {
          // Error validasi Laravel (422) - ambil pesan pertama yang ada
          final errors = body['errors'] as Map;
          if (errors.isNotEmpty) {
            pesan = (errors.values.first as List).first.toString();
          }
        }
      } catch (_) {
        // biarkan pesan default kalau body-nya bukan JSON yang diharapkan
      }
      throw Exception(pesan);
    }
  }

  static Future<Map<String, dynamic>> getGrafikTahunan({int? tahun}) async {
    final uri = Uri.parse('$baseUrl/scan-logs/grafik-tahunan').replace(
      queryParameters: tahun != null ? {'tahun': tahun.toString()} : null,
    );
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Gagal mengambil data grafik');
    }
  }

  // --- Grafik dashboard dengan breakdown per alat (khusus admin) ---
  // periode: 'mingguan' | 'bulanan' | 'tahunan'
  static Future<Map<String, dynamic>> getGrafik({String periode = 'bulanan'}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/scan-logs/grafik?periode=$periode'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Gagal mengambil data grafik');
    }
  }

  // --- Statistik peminjaman (khusus admin) ---
  static Future<Map<String, dynamic>> getStatistik({String periode = 'harian'}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/scan-logs/statistik?periode=$periode'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Gagal mengambil statistik');
    }
  }

  // --- Kelola kategori (dilihat semua, dikelola admin) ---
  static Future<List<Map<String, dynamic>>> getKategoris() async {
    final res = await http.get(Uri.parse('$baseUrl/kategoris'), headers: await _headers());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Gagal mengambil daftar kategori');
    }
  }

  static Future<void> tambahKategori({required String namaKategori, String? keterangan}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/kategoris'),
      headers: await _headers(),
      body: jsonEncode({'nama_kategori': namaKategori, 'keterangan': keterangan}),
    );
    if (res.statusCode != 201) {
      throw Exception('Gagal menambah kategori: ${res.body}');
    }
  }

  static Future<void> hapusKategori(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/kategoris/$id'), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus kategori: ${res.body}');
    }
  }

  // --- Kelola pegawai (dilihat semua - dipakai dropdown Nama Peminjam saat
  // scan/pinjam barang - tapi cuma admin yang boleh tambah/hapus) ---
  static Future<List<Map<String, dynamic>>> getPegawais() async {
    final res = await http.get(Uri.parse('$baseUrl/pegawais'), headers: await _headers());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Gagal mengambil daftar pegawai');
    }
  }

  static Future<void> tambahPegawai({required String namaPegawai, String? jabatan}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/pegawais'),
      headers: await _headers(),
      body: jsonEncode({'nama_pegawai': namaPegawai, 'jabatan': jabatan}),
    );
    if (res.statusCode != 201) {
      throw Exception('Gagal menambah pegawai: ${res.body}');
    }
  }

  static Future<void> hapusPegawai(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/pegawais/$id'), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus pegawai: ${res.body}');
    }
  }

  // --- Kelola ruangan (dilihat semua, dikelola admin) ---
  static Future<List<Map<String, dynamic>>> getRuangans() async {
    final res = await http.get(Uri.parse('$baseUrl/ruangans'), headers: await _headers());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Gagal mengambil daftar ruangan');
    }
  }

  static Future<void> tambahRuangan({
    required String namaRuangan,
    String? lokasiGedung,
    String? keterangan,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ruangans'),
      headers: await _headers(),
      body: jsonEncode({
        'nama_ruangan': namaRuangan,
        'lokasi_gedung': lokasiGedung,
        'keterangan': keterangan,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Gagal menambah ruangan: ${res.body}');
    }
  }

  static Future<void> hapusRuangan(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/ruangans/$id'), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus ruangan: ${res.body}');
    }
  }

  // --- Kelola akun (khusus admin) ---
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/users'), headers: await _headers());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Gagal mengambil daftar akun');
    }
  }

  static Future<void> tambahUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role}),
    );
    if (res.statusCode != 201) {
      throw Exception('Gagal menambah akun: ${res.body}');
    }
  }

  static Future<void> hapusUser(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/users/$id'), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus akun: ${res.body}');
    }
  }
}
