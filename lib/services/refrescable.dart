/// Diimplementasikan oleh State milik halaman-halaman utama (Tinjauan, Data,
/// Riwayat, Informasi, Pengaturan) supaya bisa di-refresh "diam-diam" setiap
/// kali menu-nya diklik — data lama tetap tampil di layar sambil data baru
/// diambil di belakang layar, jadi kerasa instan/realtime, bukan nge-blank
/// terus muter loading tiap kali pindah menu.
abstract class Refrescable {
  Future<void> refreshDiam();
}
