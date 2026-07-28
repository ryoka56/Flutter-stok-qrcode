// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Memicu download file langsung di browser lewat Blob URL sementara.
/// Ini yang dipakai portal admin (Flutter Web) untuk export laporan —
/// bytes-nya sudah diambil lewat request ber-autentikasi dari dalam app,
/// jadi tidak perlu lagi buka tab baru / nyisipin token ke URL.
Future<void> downloadBytes(List<int> bytes, String filename, String mime) async {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
