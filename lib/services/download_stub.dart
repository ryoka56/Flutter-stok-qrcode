/// Implementasi fallback untuk platform selain Web (mobile/desktop).
/// Portal admin (yang punya fitur export laporan) memang cuma dideploy
/// sebagai Flutter Web, jadi fungsi ini praktis tidak pernah terpanggil —
/// tapi tetap disediakan supaya project tetap bisa di-build untuk
/// platform lain tanpa error "library dart:html tidak ditemukan".
Future<void> downloadBytes(List<int> bytes, String filename, String mime) async {
  throw UnsupportedError(
    'Download file laporan langsung cuma didukung di versi Web. '
    'Buka portal admin lewat browser untuk export laporan.',
  );
}
