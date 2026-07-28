/// Pilih implementasi otomatis sesuai platform saat kompilasi:
/// - Flutter Web -> download_web.dart (pakai dart:html)
/// - Selainnya   -> download_stub.dart (fallback aman)
export 'download_stub.dart' if (dart.library.html) 'download_web.dart';
