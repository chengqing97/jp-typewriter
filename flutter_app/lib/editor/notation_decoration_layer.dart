import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../models/jianpu_document.dart';

final _octaveDotCharacter = RegExp(r'^[a-ac-zA-Z1-9]$');
final _beamExcludedCharacter = RegExp(r'[\s\\|()\-𝄍𝄎𝄏𝄆𝄋𝄌𝄇𝄂]');

abstract interface class JianpuNotationSource implements Listenable {
  String get text;
  List<JianpuRun> get runs;
}

enum _DecorationKind { octaveDot, beam, slur }

class _NotationDecoration {
  const _NotationDecoration({
    required this.kind,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.id,
  });

  final _DecorationKind kind;
  final double left;
  final double top;
  final double width;
  final double height;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is _NotationDecoration &&
      other.kind == kind &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height &&
      other.id == id;

  @override
  int get hashCode => Object.hash(kind, left, top, width, height, id);
}

/// Renders octave dots, beams, and slurs as ordinary positioned widgets.
/// The TextField remains the only editable surface; all decorations ignore
/// pointer events and are positioned from RenderEditable's live text geometry.
class JianpuNotationOverlay extends StatefulWidget {
  const JianpuNotationOverlay({
    super.key,
    required this.controller,
    required this.textFieldKey,
    this.color = const Color(0xFF202124),
    this.dotDiameter = 3.3,
    this.beamThickness = 1.8,
    this.beamGap = 3.2,
    this.slurThickness = 1.25,
  });

  final JianpuNotationSource controller;
  final GlobalKey textFieldKey;
  final Color color;
  final double dotDiameter;
  final double beamThickness;
  final double beamGap;
  final double slurThickness;

  @override
  State<JianpuNotationOverlay> createState() => _JianpuNotationOverlayState();
}

class _JianpuNotationOverlayState extends State<JianpuNotationOverlay> {
  final GlobalKey _overlayKey = GlobalKey();
  List<_NotationDecoration> _decorations = const [];
  RenderEditable? _observedEditable;
  bool _geometryUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleGeometryUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleGeometryUpdate();
    });
  }

  @override
  void didUpdateWidget(covariant JianpuNotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleGeometryUpdate);
      widget.controller.addListener(_scheduleGeometryUpdate);
    }
    _scheduleGeometryUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleGeometryUpdate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleGeometryUpdate);
    _observeEditable(null);
    super.dispose();
  }

  void _scheduleGeometryUpdate() {
    if (!mounted || _geometryUpdateScheduled) return;
    _geometryUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryUpdateScheduled = false;
      if (!mounted) return;
      _updateGeometry();
    });
  }

  void _observeEditable(RenderEditable? editable) {
    if (identical(editable, _observedEditable)) return;
    _observedEditable?.offset.removeListener(_scheduleGeometryUpdate);
    _observedEditable = editable;
    _observedEditable?.offset.addListener(_scheduleGeometryUpdate);
  }

  RenderEditable? _findRenderEditable() {
    final context = widget.textFieldKey.currentContext;
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

  Rect? _glyphRect(
    RenderEditable editable,
    RenderBox overlayBox,
    int offset,
    int length,
  ) {
    if (offset < 0 || offset + length > widget.controller.text.length) {
      return null;
    }

    Rect toOverlayCoordinates(Rect rect) {
      final topLeft =
          overlayBox.globalToLocal(editable.localToGlobal(rect.topLeft));
      final bottomRight =
          overlayBox.globalToLocal(editable.localToGlobal(rect.bottomRight));
      return Rect.fromPoints(topLeft, bottomRight);
    }

    final start = toOverlayCoordinates(
      editable.getLocalRectForCaret(TextPosition(offset: offset)),
    );
    final end = toOverlayCoordinates(
      editable.getLocalRectForCaret(TextPosition(offset: offset + length)),
    );

    return Rect.fromLTRB(
      start.center.dx < end.center.dx ? start.center.dx : end.center.dx,
      start.top < end.top ? start.top : end.top,
      start.center.dx > end.center.dx ? start.center.dx : end.center.dx,
      start.bottom > end.bottom ? start.bottom : end.bottom,
    );
  }

  void _updateGeometry() {
    final editable = _findRenderEditable();
    _observeEditable(editable);
    final overlayObject = _overlayKey.currentContext?.findRenderObject();
    if (editable == null ||
        overlayObject is! RenderBox ||
        !editable.attached ||
        !overlayObject.attached ||
        widget.controller.text.isEmpty) {
      if (_decorations.isNotEmpty) {
        setState(() => _decorations = const []);
      }
      return;
    }

    final next = <_NotationDecoration>[];
    final runs = widget.controller.runs;
    final slurGroups = <String, List<int>>{};
    var offset = 0;

    for (var runIndex = 0; runIndex < runs.length; runIndex++) {
      final run = runs[runIndex];

      // Octave dots are separate circular widgets, centered on each glyph.
      if (run.octave != 0) {
        var characterOffset = 0;
        for (final rune in run.text.runes) {
          final character = String.fromCharCode(rune);
          final length = character.length;
          if (_octaveDotCharacter.hasMatch(character)) {
            final rect = _glyphRect(
              editable,
              overlayObject,
              offset + characterOffset,
              length,
            );
            if (rect != null) {
              for (var dot = 0; dot < run.octave.abs(); dot++) {
                final belowBeamOffset = run.beam > 0
                    ? 2.5 + (run.beam - 1) * widget.beamGap + 4.5
                    : 3.5;
                final centerY = run.octave > 0
                    ? rect.top - 3.5 - dot * 4.2
                    : rect.bottom + belowBeamOffset + dot * 4.2;
                next.add(_NotationDecoration(
                  kind: _DecorationKind.octaveDot,
                  left: rect.center.dx - widget.dotDiameter / 2,
                  top: centerY - widget.dotDiameter / 2,
                  width: widget.dotDiameter,
                  height: widget.dotDiameter,
                  id: 'dot-$offset-$dot',
                ));
              }
            }
          }
          characterOffset += length;
        }
      }

      // Each uninterrupted beamable run on a visual line becomes a set of
      // thin rectangular widgets, one for each beam level.
      if (run.beam > 0) {
        Rect? first;
        Rect? last;
        double? lineTop;
        var bottom = 0.0;
        var characterOffset = 0;

        void flushBeam() {
          if (first != null && last != null) {
            for (var level = 0; level < run.beam; level++) {
              next.add(_NotationDecoration(
                kind: _DecorationKind.beam,
                left: first!.left,
                top: bottom + 2.5 + level * widget.beamGap,
                width: (last!.right - first!.left).clamp(0.0, double.infinity).toDouble(),
                height: widget.beamThickness,
                id: 'beam-$runIndex-$level-${first!.left}',
              ));
            }
          }
          first = null;
          last = null;
          lineTop = null;
          bottom = 0;
        }

        for (final rune in run.text.runes) {
          final character = String.fromCharCode(rune);
          final length = character.length;
          if (!_beamExcludedCharacter.hasMatch(character)) {
            final rect = _glyphRect(
              editable,
              overlayObject,
              offset + characterOffset,
              length,
            );
            if (rect == null) {
              flushBeam();
            } else {
              if (first != null && (rect.top - lineTop!).abs() > 2) {
                flushBeam();
              }
              first ??= rect;
              last = rect;
              lineTop ??= rect.top;
              if (rect.bottom > bottom) bottom = rect.bottom;
            }
          } else {
            flushBeam();
          }
          characterOffset += length;
        }
        flushBeam();
      }

      if (run.slurId != null) {
        slurGroups.putIfAbsent(run.slurId!, () => <int>[]).addAll(
              List<int>.generate(run.text.length, (i) => offset + i),
            );
      }
      offset += run.text.length;
    }

    // Slurs are shallow rounded-rectangle caps: only the top border is
    // visible, with rounded top corners. They intentionally are not curved
    // like conventional music-notation slurs.
    for (final entry in slurGroups.entries) {
      final positions = entry.value;
      if (positions.isEmpty) continue;
      final first = _glyphRect(editable, overlayObject, positions.first, 1);
      final last = _glyphRect(editable, overlayObject, positions.last, 1);
      if (first == null || last == null) continue;
      if ((first.top - last.top).abs() > (first.bottom - first.top) * 1.5) {
        continue;
      }

      final width = last.right - first.left;
      if (width <= 0) continue;
      final archHeight = (width * .12).clamp(5.0, 18.0).toDouble();
      next.add(_NotationDecoration(
        kind: _DecorationKind.slur,
        left: first.left,
        top: first.top - 5 - archHeight,
        width: width,
        height: archHeight,
        id: 'slur-${entry.key}',
      ));
    }

    if (!_sameDecorations(_decorations, next)) {
      setState(() => _decorations = next);
    }
  }

  bool _sameDecorations(
    List<_NotationDecoration> a,
    List<_NotationDecoration> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _buildDecoration(_NotationDecoration decoration) {
    switch (decoration.kind) {
      case _DecorationKind.octaveDot:
        return Container(
          width: decoration.width,
          height: decoration.height,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        );
      case _DecorationKind.beam:
        return Container(
          width: decoration.width,
          height: decoration.height,
          color: widget.color,
        );
      case _DecorationKind.slur:
        return Container(
          width: decoration.width,
          height: decoration.height,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: widget.color,
                width: widget.slurThickness,
              ),
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(decoration.height),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Also refresh after parent layout changes (e.g. page width or rotation).
    _scheduleGeometryUpdate();
    return IgnorePointer(
      child: Stack(
        key: _overlayKey,
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          for (final decoration in _decorations)
            Positioned(
              key: ValueKey(decoration.id),
              left: decoration.left,
              top: decoration.top,
              width: decoration.width,
              height: decoration.height,
              child: _buildDecoration(decoration),
            ),
        ],
      ),
    );
  }
}
