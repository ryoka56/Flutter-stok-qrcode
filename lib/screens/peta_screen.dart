import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/titik_lokasi.dart';
import '../services/api_service.dart';

class PetaScreen extends StatefulWidget {
  const PetaScreen({super.key});

  @override
  State<PetaScreen> createState() => _PetaScreenState();
}

class _PetaScreenState extends State<PetaScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  late Future<List<TitikLokasi>> _futureTitik;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _futureTitik = ApiService.getPetaLokasi();
  }

  void _muatUlang() {
    setState(() {
      _futureTitik = ApiService.getPetaLokasi();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Peta Lokasi Barang'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _muatUlang),
        ],
      ),
      body: FutureBuilder<List<TitikLokasi>>(
        future: _futureTitik,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final titikList = snapshot.data ?? [];
          if (titikList.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada barang yang pernah discan.\n'
                  'Titik lokasi akan muncul setelah barang dipindai '
                  'dan lokasinya dicatat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }

          // Pusatkan peta di titik pertama sebagai default
          final pusat = LatLng(titikList.first.latitude, titikList.first.longitude);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: pusat,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.aset_gudang_komdigi',
                  ),
                  MarkerLayer(
                    markers: titikList.map((t) {
                      return Marker(
                        point: LatLng(t.latitude, t.longitude),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _tampilkanDetailTitik(context, t),
                          child: const Icon(
                            Icons.location_on,
                            color: tombolCyan,
                            size: 40,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Info jumlah titik
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    '${titikList.length} barang tercatat lokasinya. Tap ikon untuk detail.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _tampilkanDetailTitik(BuildContext context, TitikLokasi t) {
    final waktuLokal = t.scannedAt.toLocal();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.namaBarang,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${t.kodeAset} • ${t.kategori}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: tombolCyan),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t.lokasiInput)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.black45),
                  const SizedBox(width: 6),
                  Text(
                    '${waktuLokal.day}/${waktuLokal.month}/${waktuLokal.year} '
                    '${waktuLokal.hour.toString().padLeft(2, '0')}:'
                    '${waktuLokal.minute.toString().padLeft(2, '0')} WIB',
                    style: const TextStyle(color: Colors.black45),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Koordinat: ${t.latitude.toStringAsFixed(6)}, ${t.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
