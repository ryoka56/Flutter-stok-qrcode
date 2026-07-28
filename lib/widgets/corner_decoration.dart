import 'package:flutter/material.dart';

/// Ornamen bentuk geometris di pojok layar, meniru elemen dekoratif
/// pada desain Figma (kombinasi kotak biru muda, biru tua, dan kuning).
class CornerDecoration extends StatelessWidget {
  final bool topLeft; // true = pojok kiri atas, false = pojok kanan bawah
  const CornerDecoration({super.key, required this.topLeft});

  static const Color biruMuda = Color(0xFF6FC6E8);
  static const Color biruTua = Color(0xFF3A8FC0);
  static const Color kuning = Color(0xFFE8D96A);
  static const Color merahMuda = Color(0xFFB06B72);

  @override
  Widget build(BuildContext context) {
    // Susunan kotak-kotak membentuk pola tangga/step seperti di desain
    final blok = SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _kotak(70, biruMuda, radiusTL: 24),
          ),
          Positioned(
            left: 0,
            top: 70,
            child: _kotak(40, biruTua, radiusBL: 16),
          ),
          Positioned(
            left: 45,
            top: 70,
            child: _kotak(28, kuning, radiusTL: 6, radiusBR: 6),
          ),
        ],
      ),
    );

    if (topLeft) {
      return Positioned(left: 0, top: 0, child: blok);
    }
    return Positioned(
      right: 0,
      bottom: 0,
      child: Transform.rotate(angle: 3.14159, child: blok),
    );
  }

  Widget _kotak(
    double size,
    Color color, {
    double radiusTL = 0,
    double radiusTR = 0,
    double radiusBL = 0,
    double radiusBR = 0,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusTL),
          topRight: Radius.circular(radiusTR),
          bottomLeft: Radius.circular(radiusBL),
          bottomRight: Radius.circular(radiusBR),
        ),
      ),
    );
  }
}

/// Aksen kotak kecil warna merah muda, dipakai dekat tombol/pojok bawah
class SmallSquareAccent extends StatelessWidget {
  const SmallSquareAccent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: CornerDecoration.merahMuda,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
