import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../models/jianpu_document.dart';

final _octaveDotCharacter = RegExp(r'^[a-ac-zA-Z1-9]$');
final _beamExcludedCharacter = RegExp(r'[\s\\|()\-𝄍𝄎𝄏𝄆𝄋𝄌𝄇𝄂]');

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
    required this.textFieldKey,
    required this.paintKey,
  }) : super(repaint: controller);

  final JianpuNotationSource controller;
  final TextStyle baseStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final GlobalKey textFieldKey;
  final GlobalKey paintKey;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || controller.text.isEmpty) return;

    final runs = controller.runs;
    final editable = _findRenderEditable();
    final paintBox = paintKey.currentContext?.findRenderObject();
    final canUseEditableGeometry = editable != null && paintBox is RenderBox;
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
      if (canUseEditableGeometry && run.beam > 0) {
        _paintBeams(canvas, editable, paintBox, run, offset, beamPaint);
      }
      var characterOffset = 0;
      for (final rune in run.text.runes) {
        final character = String.fromCharCode(rune);
        final characterLength = character.length;
        final textOffset = offset + characterOffset;
        final boxesForGlyph = _boxes(layout, textOffset, characterLength);
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
        if (run.octave != 0 && _octaveDotCharacter.hasMatch(character)) {
          final box = canUseEditableGeometry
              ? _actualGlyphRect(
                  editable, paintBox, textOffset, characterLength)
              : null;
          if (box != null) {
            final x = box.center.dx;
            for (var dot = 0; dot < run.octave.abs(); dot++) {
              // Negative-octave dots belong below the beam stack. Keep
              // the first dot below the lowest beam, then stack additional
              // octave dots with the usual spacing.
              final belowBeamOffset = run.beam > 0
                  ? 2.5 + (run.beam - 1) * 3.2 + 4.5
                  : 3.5;
              final y = run.octave > 0
                  ? box.top - 3.5 - dot * 4.2
                  : box.bottom + belowBeamOffset + dot * 4.2;
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
    RenderEditable editable,
    RenderBox paintBox,
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
        final box = _actualGlyphRect(
          editable,
          paintBox,
          offset + characterOffset,
          characterLength,
        );
        if (box == null) {
          flush();
        } else {
          final textBox = TextBox.fromLTRBD(
            box.left,
            box.top,
            box.right,
            box.bottom,
            TextDirection.ltr,
          );
          if (first != null && (box.top - lineTop!).abs() > 2) flush();
          first ??= textBox;
          last = textBox;
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

  RenderEditable? _findRenderEditable() {
    final context = textFieldKey.currentContext;
    if (context is! Element) return null;

    RenderEditable? result;
    void visit(Element element) {
      if (result != null) return;
      final renderObject = element.findRenderObject();
      if (renderObject is RenderEditable) {
        result = renderObject;
        return;
      }
      element.visitChildElements(visit);
    }

    visit(context);
    return result;
  }

  Rect? _actualGlyphRect(
    RenderEditable editable,
    RenderBox paintBox,
    int offset,
    int length,
  ) {
    if (offset < 0 || offset + length > controller.text.length) return null;

    Rect toPaintCoordinates(Rect rect) {
      final topLeft =
          paintBox.globalToLocal(editable.localToGlobal(rect.topLeft));
      final bottomRight =
          paintBox.globalToLocal(editable.localToGlobal(rect.bottomRight));
      return Rect.fromPoints(topLeft, bottomRight);
    }

    final start = toPaintCoordinates(
      editable.getLocalRectForCaret(TextPosition(offset: offset)),
    );
    final end = toPaintCoordinates(
      editable.getLocalRectForCaret(TextPosition(offset: offset + length)),
    );
    return Rect.fromLTRB(
      start.center.dx < end.center.dx ? start.center.dx : end.center.dx,
      start.top < end.top ? start.top : end.top,
      start.center.dx > end.center.dx ? start.center.dx : end.center.dx,
      start.bottom > end.bottom ? start.bottom : end.bottom,
    );
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
