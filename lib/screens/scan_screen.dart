import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../models/asset.dart';
import 'input_lokasi_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);
  bool _sedangProses = false;

  Future<void> _tanganiHasilScan(String kodeAset) async {
    if (_sedangProses) return;
    setState(() => _sedangProses = true);

    try {
      final Asset asset = await ApiService.getAssetByKode(kodeAset);
      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InputLokasiScreen(asset: asset)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _sedangProses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan QR-Code Barang'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final kode = barcodes.first.rawValue;
                if (kode != null) _tanganiHasilScan(kode);
              }
            },
          ),

          // Overlay gelap dengan lubang kotak di tengah (frame pemindai)
          IgnorePointer(
            child: Container(
              decoration: const ShapeDecoration(
                shape: _ScannerOverlayShape(
                  borderColor: tombolCyan,
                  borderWidth: 4,
                  cutOutSize: 250,
                ),
                color: Colors.black54,
              ),
            ),
          ),

          const Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke QR-code pada barang',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),

          if (_sedangProses)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: tombolCyan),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shape custom untuk bikin overlay gelap dengan lubang kotak di tengah,
/// meniru tampilan frame scanner pada umumnya.
class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double cutOutSize;

  const _ScannerOverlayShape({
    required this.borderColor,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final cutOutRect = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );
    return Path()
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final cutOutRect = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, const Radius.circular(20)),
      paint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
