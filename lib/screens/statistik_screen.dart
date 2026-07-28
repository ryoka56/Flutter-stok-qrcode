import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  final List<Map<String, String>> _pilihanPeriode = const [
    {'value': 'harian', 'label': 'Harian'},
    {'value': 'mingguan', 'label': 'Mingguan'},
    {'value': 'bulanan', 'label': 'Bulanan'},
    {'value': 'tahunan', 'label': 'Tahunan'},
    {'value': 'semua', 'label': 'Seluruh'},
  ];

  String _periodeTerpilih = 'harian';
  late Future<Map<String, dynamic>> _futureStatistik;

  @override
  void initState() {
    super.initState();
    _futureStatistik = ApiService.getStatistik(periode: _periodeTerpilih);
  }

  void _muatUlang() {
    setState(() {
      _futureStatistik = ApiService.getStatistik(periode: _periodeTerpilih);
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
        title: const Text('Statistik Peminjaman'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _muatUlang),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: _pilihanPeriode.map((p) {
                final terpilih = p['value'] == _periodeTerpilih;
                return ChoiceChip(
                  label: Text(p['label']!),
                  selected: terpilih,
                  selectedColor: tombolCyan.withOpacity(0.25),
                  onSelected: (_) {
                    setState(() => _periodeTerpilih = p['value']!);
                    _muatUlang();
                  },
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _futureStatistik,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final data = snapshot.data!;
                final total = data['total'] ?? 0;
                final rincian = (data['rincian_harian'] as List?) ?? [];
                final barangTerpopuler = (data['barang_terpopuler'] as List?) ?? [];

                return RefreshIndicator(
                  onRefresh: () async => _muatUlang(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: tombolCyan,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Peminjaman',
                                style: TextStyle(color: Colors.black54, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('$total',
                                style: const TextStyle(
                                    fontSize: 42, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text(_labelPeriode(_periodeTerpilih),
                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (rincian.isNotEmpty) ...[
                        const Text('Rincian per Hari',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        ..._buildRincianChart(rincian),
                        const SizedBox(height: 24),
                      ],
                      if (barangTerpopuler.isNotEmpty) ...[
                        const Text('Barang Paling Sering Dipinjam',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        ...barangTerpopuler.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: tombolCyan.withOpacity(0.2),
                                  child: Text('${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(item['nama_barang'] ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Text('${item['jumlah']}x',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: tombolCyan)),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (rincian.isEmpty && barangTerpopuler.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Text('Belum ada data peminjaman pada periode ini.',
                                style: TextStyle(color: Colors.black45)),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _labelPeriode(String periode) {
    switch (periode) {
      case 'harian':
        return 'Hari ini';
      case 'mingguan':
        return 'Minggu ini';
      case 'bulanan':
        return 'Bulan ini';
      case 'tahunan':
        return 'Tahun ini';
      default:
        return 'Sepanjang waktu';
    }
  }

  List<Widget> _buildRincianChart(List rincian) {
    final maxJumlah = rincian
        .map((r) => (r['jumlah'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return rincian.map<Widget>((r) {
      final jumlah = (r['jumlah'] as num).toDouble();
      final proporsi = maxJumlah > 0 ? jumlah / maxJumlah : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(r['tanggal'] ?? '-',
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: proporsi.clamp(0.05, 1.0),
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: tombolCyan,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              child: Text('${r['jumlah']}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }).toList();
  }
}
