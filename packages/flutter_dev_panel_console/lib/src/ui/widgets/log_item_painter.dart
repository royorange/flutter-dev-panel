import 'package:flutter/material.dart';

/// Custom painter for dashed line
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  
  DashedLinePainter({
    required this.color,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}