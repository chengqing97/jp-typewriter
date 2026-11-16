import 'package:flutter/material.dart';

import '../models/jianpu_document.dart';


abstract interface class JianpuNotationSource implements Listenable {
  String get text;
  List<JianpuRun> get runs;
}

/// Paints octave dots above/below note digits without adding characters to the
/// editable text. Keeping the dots out of the TextSpan tree preserves the
/// controller's UTF-16 offsets and physical-keyboard cursor behaviour.
class OctaveDotPainter extends CustomPainter {
  OctaveDotPainter({
    required this.controller,
    required this.baseStyle,
    required this.textDirection,
    required this.textScaler,
  }) : super(repaint: controller);

  final JianpuNotationSource controller;
  final TextStyle baseStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || controller.text.isEmpty) return;

    final spans = <InlineSpan>[];
    for (final run in controller.runs) {
      spans.add(TextSpan(
        text: run.text,
        style: TextStyle(
          fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
          fontSize: run.superscript ? 15 : null,
        ),
      ));
    }

    final layout = TextPainter(
      text: TextSpan(style: baseStyle, children: spans),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);

    final paint = Paint()
      ..color = baseStyle.color ?? Colors.black
      ..style = PaintingStyle.fill;

    var documentOffset = 0;
    for (final run in controller.runs) {
      if (run.octave != 0) {
        for (var i = 0; i < run.text.length; i++) {
          final codeUnit = run.text.codeUnitAt(i);
          // Octave marks belong to numbered notes, not spaces, bars or dashes.
          if (codeUnit < 0x31 || codeUnit > 0x37) continue;

          final boxes = layout.getBoxesForSelection(
            TextSelection(
              baseOffset: documentOffset + i,
              extentOffset: documentOffset + i + 1,
            ),
          );
          if (boxes.isEmpty) continue;

          final box = boxes.first;
          final centerX = (box.left + box.right) / 2;
          final radius = 1.7;
          for (var dot = 0; dot < run.octave.abs(); dot++) {
            final y = run.octave > 0
                ? box.top - 3.5 - dot * 4.5
                : box.bottom + 3.5 + dot * 4.5;
            canvas.drawCircle(Offset(centerX, y), radius, paint);
          }
        }
      }
      documentOffset += run.text.length;
    }

    layout.dispose();
  }

  @override
  bool shouldRepaint(covariant OctaveDotPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.baseStyle != baseStyle ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.textScaler != textScaler;
  }
}
