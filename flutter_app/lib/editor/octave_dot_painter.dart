import 'package:material_ui/material_ui.dart';

import '../models/jianpu_document.dart';

final _octaveDotCharacter = RegExp(r'^[a-ac-zA-Z1-9]
abstract interface class JianpuNotationSource implements Listenable {
  String get text;
  List<JianpuRun> get runs;
}

/// Draws notation marks in a separate layer so they never become editable
/// characters and never affect TextSelection offsets.
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

    final runs = controller.runs;
    final spans = <InlineSpan>[
      for (final run in runs)
        TextSpan(
          text: run.text,
          style: TextStyle(
            fontFamily: baseStyle.fontFamily,
            color: run.superscript ? Colors.transparent : null,
            fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
            fontSize: run.superscript ? (baseStyle.fontSize ?? 23) * .68 : null,
          ),
        ),
    ];
    final layout = TextPainter(
      text: TextSpan(style: baseStyle, children: spans),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);

    final ink = Paint()
      ..color = baseStyle.color ?? Colors.black
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;
    final beamPaint = Paint()
      ..color = baseStyle.color ?? Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;
    final slurPaint = Paint()
      ..color = baseStyle.color ?? Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    var offset = 0;
    final slurGroups = <String, List<int>>{};
    for (final run in runs) {
      if (run.beam > 0) _paintBeams(canvas, layout, run, offset, beamPaint);
      var characterOffset = 0;
      for (final rune in run.text.runes) {
        final character = String.fromCharCode(rune);
        final characterLength = character.length;
        final textOffset = offset + characterOffset;
        final boxesForGlyph =
            _boxes(layout, textOffset, characterLength);
        if (run.superscript && boxesForGlyph.isNotEmpty) {
          final glyph = TextPainter(
            text: TextSpan(
              text: character,
              style: TextStyle(
                fontFamily: baseStyle.fontFamily,
                fontSize: (baseStyle.fontSize ?? 23) * .68,
                color: baseStyle.color ?? Colors.black,
                fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            textDirection: textDirection,
            textScaler: textScaler,
          )..layout();
          glyph.paint(
            canvas,
            Offset(boxesForGlyph.first.left, boxesForGlyph.first.top - 5.5),
          );
          glyph.dispose();
        }
        if (run.octave != 0 &&
            _octaveDotCharacter.hasMatch(character)) {
          final boxes = _boxes(layout, textOffset, characterLength);
          if (boxes.isNotEmpty) {
            final box = boxes.first;
            final x = (box.left + box.right) / 2;
            for (var dot = 0; dot < run.octave.abs(); dot++) {
              final y = run.octave > 0
                  ? box.top - 3.5 - dot * 4.2
                  : box.bottom + 3.5 + dot * 4.2;
              canvas.drawCircle(Offset(x, y), 1.65, ink);
            }
          }
        }
        characterOffset += characterLength;
      }
      if (run.slurId != null) {
        slurGroups.putIfAbsent(run.slurId!, () => <int>[]).addAll(
              List<int>.generate(run.text.length, (i) => offset + i),
            );
      }
      offset += run.text.length;
    }

    // A slur spans all consecutive text runs carrying the same slur id.
    for (final positions in slurGroups.values) {
      if (positions.isEmpty) continue;
      final firstBoxes = _boxes(layout, positions.first);
      final lastBoxes = _boxes(layout, positions.last);
      if (firstBoxes.isEmpty || lastBoxes.isEmpty) continue;
      final first = firstBoxes.first;
      final last = lastBoxes.first;
      if ((first.top - last.top).abs() > (first.bottom - first.top) * 1.5) {
        continue;
      }
      final start = Offset(first.left, first.top - 5);
      final end = Offset(last.right, last.top - 5);
      final width = (end.dx - start.dx).abs();
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          (start.dx + end.dx) / 2,
          start.dy - (width * .12).clamp(5.0, 18.0),
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, slurPaint);
    }

    layout.dispose();
  }

  void _paintBeams(
    Canvas canvas,
    TextPainter layout,
    JianpuRun run,
    int offset,
    Paint paint,
  ) {
    TextBox? first;
    TextBox? last;
    double? lineTop;
    var bottom = 0.0;

    void flush() {
      if (first != null && last != null) {
        for (var level = 0; level < run.beam; level++) {
          final y = bottom + 2.5 + level * 3.2;
          canvas.drawLine(
              Offset(first!.left, y), Offset(last!.right, y), paint);
        }
      }
      first = null;
      last = null;
      lineTop = null;
      bottom = 0;
    }

    var characterOffset = 0;
    for (final rune in run.text.runes) {
      final character = String.fromCharCode(rune);
      final characterLength = character.length;
      if (!_beamExcludedCharacter.hasMatch(character)) {
        final boxes =
            _boxes(layout, offset + characterOffset, characterLength);
        if (boxes.isEmpty) {
          flush();
        } else {
          final box = boxes.first;
          if (first != null && (box.top - lineTop!).abs() > 2) flush();
          first ??= box;
          last = box;
          lineTop ??= box.top;
          if (box.bottom > bottom) bottom = box.bottom;
        }
      } else {
        flush();
      }
      characterOffset += characterLength;
    }
    flush();
  }

  List<TextBox> _boxes(TextPainter painter, int offset, [int length = 1]) {
    return painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + length),
    );
  }

  @override
  bool shouldRepaint(covariant OctaveDotPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.baseStyle != baseStyle ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler;
}
);
final _beamExcludedCharacter = RegExp(r'[\\s\\\\|()\\-𝄍𝄎𝄏𝄆𝄋𝄌𝄇𝄂]');

abstract interface class JianpuNotationSource implements Listenable {
  String get text;
  List<JianpuRun> get runs;
}

/// Draws notation marks in a separate layer so they never become editable
/// characters and never affect TextSelection offsets.
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

    final runs = controller.runs;
    final spans = <InlineSpan>[
      for (final run in runs)
        TextSpan(
          text: run.text,
          style: TextStyle(
            fontFamily: baseStyle.fontFamily,
            color: run.superscript ? Colors.transparent : null,
            fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
            fontSize: run.superscript ? (baseStyle.fontSize ?? 23) * .68 : null,
          ),
        ),
    ];
    final layout = TextPainter(
      text: TextSpan(style: baseStyle, children: spans),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);

    final ink = Paint()
      ..color = baseStyle.color ?? Colors.black
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;
    final beamPaint = Paint()
      ..color = baseStyle.color ?? Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;
    final slurPaint = Paint()
      ..color = baseStyle.color ?? Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    var offset = 0;
    final slurGroups = <String, List<int>>{};
    for (final run in runs) {
      if (run.beam > 0) _paintBeams(canvas, layout, run, offset, beamPaint);
      for (var i = 0; i < run.text.length; i++) {
        final code = run.text.codeUnitAt(i);
        final boxesForGlyph = _boxes(layout, offset + i);
        if (run.superscript && boxesForGlyph.isNotEmpty) {
          final glyph = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(code),
              style: TextStyle(
                fontFamily: baseStyle.fontFamily,
                fontSize: (baseStyle.fontSize ?? 23) * .68,
                color: baseStyle.color ?? Colors.black,
                fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            textDirection: textDirection,
            textScaler: textScaler,
          )..layout();
          glyph.paint(
            canvas,
            Offset(boxesForGlyph.first.left, boxesForGlyph.first.top - 5.5),
          );
          glyph.dispose();
        }
        if (run.octave != 0 && code >= 0x31 && code <= 0x37) {
          final boxes = _boxes(layout, offset + i);
          if (boxes.isNotEmpty) {
            final box = boxes.first;
            final x = (box.left + box.right) / 2;
            for (var dot = 0; dot < run.octave.abs(); dot++) {
              final y = run.octave > 0
                  ? box.top - 3.5 - dot * 4.2
                  : box.bottom + 3.5 + dot * 4.2;
              canvas.drawCircle(Offset(x, y), 1.65, ink);
            }
          }
        }
      }
      if (run.slurId != null) {
        slurGroups.putIfAbsent(run.slurId!, () => <int>[]).addAll(
              List<int>.generate(run.text.length, (i) => offset + i),
            );
      }
      offset += run.text.length;
    }

    // A slur spans all consecutive text runs carrying the same slur id.
    for (final positions in slurGroups.values) {
      if (positions.isEmpty) continue;
      final firstBoxes = _boxes(layout, positions.first);
      final lastBoxes = _boxes(layout, positions.last);
      if (firstBoxes.isEmpty || lastBoxes.isEmpty) continue;
      final first = firstBoxes.first;
      final last = lastBoxes.first;
      if ((first.top - last.top).abs() > (first.bottom - first.top) * 1.5) {
        continue;
      }
      final start = Offset(first.left, first.top - 5);
      final end = Offset(last.right, last.top - 5);
      final width = (end.dx - start.dx).abs();
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          (start.dx + end.dx) / 2,
          start.dy - (width * .12).clamp(5.0, 18.0),
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, slurPaint);
    }

    layout.dispose();
  }

  void _paintBeams(
    Canvas canvas,
    TextPainter layout,
    JianpuRun run,
    int offset,
    Paint paint,
  ) {
    TextBox? first;
    TextBox? last;
    double? lineTop;
    var bottom = 0.0;

    void flush() {
      if (first != null && last != null) {
        for (var level = 0; level < run.beam; level++) {
          final y = bottom + 2.5 + level * 3.2;
          canvas.drawLine(
              Offset(first!.left, y), Offset(last!.right, y), paint);
        }
      }
      first = null;
      last = null;
      lineTop = null;
      bottom = 0;
    }

    for (var i = 0; i < run.text.length; i++) {
      final code = run.text.codeUnitAt(i);
      if (code >= 0x31 && code <= 0x37) {
        final boxes = _boxes(layout, offset + i);
        if (boxes.isEmpty) {
          flush();
          continue;
        }
        final box = boxes.first;
        if (first != null && (box.top - lineTop!).abs() > 2) flush();
        first ??= box;
        last = box;
        lineTop ??= box.top;
        if (box.bottom > bottom) bottom = box.bottom;
      } else if (code != 0x20 || first == null) {
        flush();
      }
      // Spaces between selected notes remain part of one continuous beam.
    }
    flush();
  }

  List<TextBox> _boxes(TextPainter painter, int offset) {
    return painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
  }

  @override
  bool shouldRepaint(covariant OctaveDotPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.baseStyle != baseStyle ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler;
}
