import 'package:material_ui/material_ui.dart';

import '../models/jianpu_document.dart';
import 'notation_decoration_layer.dart';

class _JianpuEditorSnapshot {
  const _JianpuEditorSnapshot({
    required this.text,
    required this.runs,
    required this.selection,
  });

  final String text;
  final List<JianpuRun> runs;
  final TextSelection selection;
}

/// First editing-engine spike: use Flutter's single EditableText surface,
/// rather than one widget per note or a webview contenteditable element.
/// Keeps a single editable text surface while rendering per-range Jianpu styles.
class JianpuEditingController extends TextEditingController
    implements JianpuNotationSource {
  JianpuEditingController({required String text}) : super(text: text) {
    _lastText = text;
    _runs = text.isEmpty ? <JianpuRun>[] : <JianpuRun>[JianpuRun(text: text)];
    _lastKnownSelection = selection;
    addListener(_reconcileTextChanges);
  }

  late String _lastText;
  late List<JianpuRun> _runs;
  late TextSelection _lastKnownSelection;
  final List<_JianpuEditorSnapshot> _undoStack = [];
  final List<_JianpuEditorSnapshot> _redoStack = [];
  bool _isTypingGroup = false;
  DateTime? _lastTypingTime;
  int? _lastTypingCaret;

  static const _typingGroupInterval = Duration(milliseconds: 750);

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  _JianpuEditorSnapshot _snapshot() => _JianpuEditorSnapshot(
        text: text,
        runs: List<JianpuRun>.of(_runs),
        selection: selection,
      );

  void _recordUndo() {
    _isTypingGroup = false;
    _lastTypingTime = null;
    _lastTypingCaret = null;
    _undoStack.add(_snapshot());
    if (_undoStack.length > 200) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (!canUndo) return;
    _isTypingGroup = false;
    _lastTypingTime = null;
    _lastTypingCaret = null;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
  }

  void redo() {
    if (!canRedo) return;
    _isTypingGroup = false;
    _lastTypingTime = null;
    _lastTypingCaret = null;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
  }

  void _restore(_JianpuEditorSnapshot snapshot) {
    _isTypingGroup = false;
    _lastTypingTime = null;
    _lastTypingCaret = null;
    _runs = List<JianpuRun>.of(snapshot.runs);
    _lastText = snapshot.text;
    value = TextEditingValue(
      text: snapshot.text,
      selection: snapshot.selection,
    );
    _lastKnownSelection = snapshot.selection;
    notifyListeners();
  }

  @override
  List<JianpuRun> get runs => List.unmodifiable(_runs);

  void loadRuns(List<JianpuRun> runs) {
    _runs = List<JianpuRun>.of(runs);
    _lastText = _runs.map((run) => run.text).join();
    final caret = TextSelection.collapsed(offset: _lastText.length);
    value = TextEditingValue(text: _lastText, selection: caret);
    _lastKnownSelection = caret;
    // History starts empty for every loaded document. The first user edit
    // records its own pre-edit state; seeding this stack creates a duplicate
    // initial undo step.
    _undoStack.clear();
    _redoStack.clear();
    _isTypingGroup = false;
    _lastTypingTime = null;
    _lastTypingCaret = null;
    notifyListeners();
  }

  void formatRange(
      int start, int end, JianpuRun Function(JianpuRun) transform) {
    if (start < 0 || end > text.length || start >= end) return;
    _recordUndo();
    final updated = <JianpuRun>[];
    var offset = 0;
    for (final run in _runs) {
      final runStart = offset;
      final runEnd = offset + run.text.length;
      offset = runEnd;

      if (runEnd <= start || runStart >= end) {
        _appendRun(updated, run);
        continue;
      }

      final localStart = (start - runStart).clamp(0, run.text.length).toInt();
      final localEnd = (end - runStart).clamp(0, run.text.length).toInt();
      if (localStart > 0) {
        _appendRun(
            updated, run.copyWith(text: run.text.substring(0, localStart)));
      }
      if (localEnd > localStart) {
        _appendRun(
          updated,
          transform(
              run.copyWith(text: run.text.substring(localStart, localEnd))),
        );
      }
      if (localEnd < run.text.length) {
        _appendRun(updated, run.copyWith(text: run.text.substring(localEnd)));
      }
    }
    _runs = updated;
    notifyListeners();
  }

  void replaceRangeWithRuns(int start, int end, List<JianpuRun> insertedRuns) {
    if (start < 0 || end < start || end > text.length) return;
    _recordUndo();
    final updated = <JianpuRun>[];
    var offset = 0;
    for (final run in _runs) {
      final runStart = offset, runEnd = runStart + run.text.length;
      offset = runEnd;
      final beforeEnd = runEnd.clamp(0, start).toInt();
      if (beforeEnd > runStart) {
        _appendRun(updated,
            run.copyWith(text: run.text.substring(0, beforeEnd - runStart)));
      }
    }
    for (final run in insertedRuns) {
      _appendRun(updated, run);
    }
    offset = 0;
    for (final run in _runs) {
      final runStart = offset, runEnd = runStart + run.text.length;
      offset = runEnd;
      final afterStart = runStart > end ? runStart : end;
      if (runEnd > afterStart) {
        _appendRun(updated,
            run.copyWith(text: run.text.substring(afterStart - runStart)));
      }
    }
    final insertedText = insertedRuns.map((run) => run.text).join();
    final updatedText = text.replaceRange(start, end, insertedText);
    _runs = updated;
    _lastText = updatedText;
    value = TextEditingValue(
        text: updatedText,
        selection:
            TextSelection.collapsed(offset: start + insertedText.length));
    notifyListeners();
  }

  void _appendRun(List<JianpuRun> target, JianpuRun run) {
    if (run.text.isEmpty) return;
    if (target.isNotEmpty) {
      final previous = target.last;
      if (previous.octave == run.octave &&
          previous.beam == run.beam &&
          previous.superscript == run.superscript &&
          previous.italic == run.italic &&
          previous.slurId == run.slurId) {
        target[target.length - 1] =
            previous.copyWith(text: previous.text + run.text);
        return;
      }
    }
    target.add(run);
  }

  void _reconcileTextChanges() {
    final current = text;
    final selection = value.selection;
    if (current == _lastText) {
      if (selection != _lastKnownSelection) {
        // Moving the caret or changing the selection ends the current
        // typing group, even if the next keystroke happens immediately.
        _isTypingGroup = false;
        _lastTypingTime = null;
        _lastTypingCaret = null;
      }
      _lastKnownSelection = selection;
      return;
    }

    final lengthDelta = current.length - _lastText.length;
    var insertionStart = -1;
    var isPureInsertion = false;
    if (lengthDelta > 0 &&
        selection.isValid &&
        selection.isCollapsed &&
        _lastKnownSelection.isValid &&
        _lastKnownSelection.isCollapsed) {
      insertionStart = selection.extentOffset - lengthDelta;
      isPureInsertion = insertionStart >= 0 &&
          insertionStart <= _lastText.length &&
          _lastKnownSelection.extentOffset == insertionStart &&
          _lastText.substring(0, insertionStart) ==
              current.substring(0, insertionStart) &&
          _lastText.substring(insertionStart) ==
              current.substring(insertionStart + lengthDelta);
    }

    final now = DateTime.now();
    final joinsPreviousTyping = isPureInsertion &&
        _isTypingGroup &&
        _lastTypingTime != null &&
        now.difference(_lastTypingTime!) <= _typingGroupInterval &&
        _lastTypingCaret == insertionStart;

    // TextField has already changed the text value, but _runs and _lastText
    // still describe the previous document state. Keep only the first
    // pre-typing snapshot for a continuous group of inserted characters.
    if (!joinsPreviousTyping) {
      _undoStack.add(_JianpuEditorSnapshot(
        text: _lastText,
        runs: List<JianpuRun>.of(_runs),
        selection: _lastKnownSelection,
      ));
      if (_undoStack.length > 200) _undoStack.removeAt(0);
      _redoStack.clear();
    }

    _isTypingGroup = isPureInsertion;
    _lastTypingTime = isPureInsertion ? now : null;
    _lastTypingCaret = isPureInsertion ? selection.extentOffset : null;

    // Find the smallest changed range shared by the old and new strings.
    var prefix = 0;
    while (prefix < _lastText.length &&
        prefix < current.length &&
        _lastText.codeUnitAt(prefix) == current.codeUnitAt(prefix)) {
      prefix++;
    }

    var suffix = 0;
    while (suffix < _lastText.length - prefix &&
        suffix < current.length - prefix &&
        _lastText.codeUnitAt(_lastText.length - 1 - suffix) ==
            current.codeUnitAt(current.length - 1 - suffix)) {
      suffix++;
    }

    // Repeated characters (especially spaces) make a text diff ambiguous.
    // For a pure insertion, the post-edit caret tells us the actual insertion
    // point. Prefer it when the old text is exactly preserved around it.
    if (selection.isValid && selection.isCollapsed) {
      final caret = selection.extentOffset;

      if (lengthDelta > 0) {
        // For insertion, the caret is immediately after the inserted text.
        final insertedLength = lengthDelta;
        final editStart = caret - insertedLength;
        if (editStart >= 0 &&
            editStart <= _lastText.length &&
            _lastText.substring(0, editStart) ==
                current.substring(0, editStart) &&
            _lastText.substring(editStart) ==
                current.substring(editStart + insertedLength)) {
          prefix = editStart;
          suffix = _lastText.length - prefix;
        }
      } else if (lengthDelta < 0) {
        // For deletion, the caret marks the start of the removed range.
        // This disambiguates identical adjacent characters with different
        // formatting, where a common-prefix diff may otherwise delete the
        // wrong run's character.
        final deletedLength = -lengthDelta;
        final editStart = caret;
        if (editStart >= 0 &&
            editStart + deletedLength <= _lastText.length &&
            _lastText.substring(0, editStart) ==
                current.substring(0, editStart) &&
            _lastText.substring(editStart + deletedLength) ==
                current.substring(editStart)) {
          prefix = editStart;
          suffix = _lastText.length - editStart - deletedLength;
        }
      }
    }

    final oldEnd = _lastText.length - suffix;
    final inserted = current.substring(prefix, current.length - suffix);
    final before = <JianpuRun>[];
    final after = <JianpuRun>[];

    // Split the old runs into two independent sides of the edit. Do not merge
    // them together before inserting new text: that would move the left side
    // to the right whenever both sides share the same formatting.
    var offset = 0;
    for (final run in _runs) {
      final runStart = offset;
      final runEnd = runStart + run.text.length;
      offset = runEnd;

      final beforeEnd = (runEnd < prefix ? runEnd : prefix);
      if (beforeEnd > runStart) {
        _appendRun(
          before,
          run.copyWith(text: run.text.substring(0, beforeEnd - runStart)),
        );
      }

      final afterStart = (runStart > oldEnd ? runStart : oldEnd);
      if (runEnd > afterStart) {
        _appendRun(
          after,
          run.copyWith(text: run.text.substring(afterStart - runStart)),
        );
      }
    }

    final rebuilt = <JianpuRun>[];
    for (final run in before) {
      _appendRun(rebuilt, run);
    }
    if (inserted.isNotEmpty) {
      _appendRun(rebuilt, JianpuRun(text: inserted));
    }
    for (final run in after) {
      _appendRun(rebuilt, run);
    }

    _runs = rebuilt;
    _lastText = current;
    _lastKnownSelection = selection;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    for (final run in _runs) {
      spans.add(TextSpan(
        text: run.text,
        style: TextStyle(
          fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
          fontSize: run.superscript ? 15 : null,
          color: run.superscript ? Colors.transparent : null,
        ),
      ));
    }
    return TextSpan(style: style, children: spans);
  }

  @override
  void dispose() {
    removeListener(_reconcileTextChanges);
    super.dispose();
  }
}

