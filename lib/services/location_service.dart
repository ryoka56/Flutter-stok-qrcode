import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Mengambil posisi GPS user saat ini.
  /// Melempar Exception dengan pesan yang jelas kalau izin ditolak / GPS mati.
  static Future<Position> ambilLokasiSaatIni() async {
    bool layananAktif = await Geolocator.isLocationServiceEnabled();
    if (!layananAktif) {
      throw Exception('GPS tidak aktif. Aktifkan lokasi terlebih dahulu.');
    }

    LocationPermission izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }

    if (izin == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
