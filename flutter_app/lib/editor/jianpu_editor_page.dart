import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../models/jianpu_document.dart';
import '../storage/jianpu_document_repository.dart';
import '../storage/local_jianpu_document.dart';
import 'notation_decoration_layer.dart';

const _jianpuClipboardFormat = CustomValueFormat<String>(
  applicationId: 'com.chengqing97.jptypewriter.jianpu-runs',
);

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

enum EditorFormatCommand {
  octaveUp,
  octaveDown,
  beamUp,
  beamDown,
  superscript,
  italic,
  clear,
}

class EditorFormatIntent extends Intent {
  const EditorFormatIntent(this.command);
  final EditorFormatCommand command;
}

class JianpuEditorPage extends StatefulWidget {
  const JianpuEditorPage({super.key});

  @override
  State<JianpuEditorPage> createState() => _JianpuEditorPageState();
}

class _JianpuEditorPageState extends State<JianpuEditorPage> {
  late final JianpuEditingController _controller;
  late final FocusNode _focusNode;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _editorFieldKey = GlobalKey();
  final GlobalKey _paperKey = GlobalKey();
  final GlobalKey _toolbarKey = GlobalKey();
  final JianpuDocumentRepository _repository = JianpuDocumentRepository();
  final List<LocalJianpuDocument> _documents = [];
  StreamSubscription<List<LocalJianpuDocument>>? _documentsSubscription;
  Timer? _saveTimer;
  String? _currentDocumentId;
  String _currentDocumentTitle = 'Loading documents…';
  String? _lastPersistedContent;
  bool _isLoadingDocuments = true;
  bool _showHelp = true;
  int _slurSequence = 0;
  Timer? _arrowRepeatTimer;
  final Map<int, Offset> _paperTapCandidates = {};
  Timer? _arrowRepeatInitialTimer;
  LogicalKeyboardKey? _heldArrowKey;
  double? _preferredVerticalX;

  static const _arrowRepeatDelay = Duration(milliseconds: 400);
  static const _arrowRepeatInterval = Duration(milliseconds: 45);

  static const _sample = '4 4 5 5 | 6 6 5 -\n'
      '4 4 3 3 | 2 2 1 -\n'
      '1 1 2 3 | 3 2 2 -\n'
      '1 1 2 3 | 3 2 2 -';

  @override
  void initState() {
    super.initState();
    _controller = JianpuEditingController(text: '');
    _focusNode = FocusNode(
      debugLabel: 'Jianpu editor',
      onKeyEvent: _handleRepeatKey,
    );
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
    _initializeDocuments();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _stopArrowRepeat();
    _saveTimer?.cancel();
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    final subscription = _documentsSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel().then((_) => _repository.close()));
    } else {
      unawaited(_repository.close());
    }
    super.dispose();
  }

  void _formatSelection(JianpuRun Function(JianpuRun) transform) {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    _controller.formatRange(selection.start, selection.end, transform);
    _focusNode.requestFocus();
  }

  bool get _hasSelection =>
      _controller.selection.isValid && !_controller.selection.isCollapsed;

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleSave();
  }

  String _contentFingerprint() => jsonEncode(_controller.runs
      .map((run) => {
            'text': run.text,
            'octave': run.octave,
            'beam': run.beam,
            'superscript': run.superscript,
            'italic': run.italic,
            'slurId': run.slurId,
          })
      .toList());

  Future<void> _initializeDocuments() async {
    try {
      final docs = await _repository.listDocuments();
      if (docs.isEmpty) {
        final first = await _repository.createDocument(
          title: 'Untitled Jianpu',
          runs: [const JianpuRun(text: _sample)],
        );
        _documents.add(first);
        _openDocument(first);
      } else {
        _documents.addAll(docs);
        _openDocument(docs.first);
      }
      _documentsSubscription ??=
          _repository.watchDocuments().listen((updatedDocs) {
        if (!mounted) return;
        _documents
          ..clear()
          ..addAll(updatedDocs);
        setState(() {});
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load local documents: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDocuments = false);
    }
  }

  void _openDocument(LocalJianpuDocument doc) {
    _saveTimer?.cancel();
    _currentDocumentId = doc.id;
    _currentDocumentTitle = doc.title;
    _controller.loadRuns(doc.runs);
    _lastPersistedContent = _contentFingerprint();
    _saveTimer?.cancel();
    if (mounted) setState(() {});
  }

  void _scheduleSave() {
    if (_currentDocumentId == null ||
        _isLoadingDocuments ||
        _contentFingerprint() == _lastPersistedContent) {
      return;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 650), _saveCurrentDocument);
  }

  Future<void> _saveCurrentDocument() async {
    final id = _currentDocumentId;
    if (id == null) return;
    final fingerprint = _contentFingerprint();
    if (fingerprint == _lastPersistedContent) return;
    try {
      await _repository.saveDocument(
          id: id, title: _currentDocumentTitle, runs: _controller.runs);
      if (id != _currentDocumentId) return;
      _lastPersistedContent = fingerprint;
      final docs = await _repository.listDocuments();
      if (!mounted || id != _currentDocumentId) return;
      _documents
        ..clear()
        ..addAll(docs);
      setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save document: $error')),
        );
      }
    }
  }

  Future<void> _flushPendingSave() async {
    _saveTimer?.cancel();
    await _saveCurrentDocument();
  }

  Future<void> _createDocument() async {
    await _flushPendingSave();
    final doc = await _repository
        .createDocument(title: 'Untitled Jianpu', runs: const []);
    final docs = await _repository.listDocuments();
    if (!mounted) return;
    _documents
      ..clear()
      ..addAll(docs);
    _openDocument(doc);
    Navigator.of(context).maybePop();
  }

  Future<void> _renameDocument(LocalJianpuDocument doc) async {
    if (doc.id == _currentDocumentId) {
      await _renameCurrentDocument();
      return;
    }
    var editedTitle = doc.title;
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          autofocus: true,
          controller: null,
          onChanged: (value) => editedTitle = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
          decoration: InputDecoration(hintText: doc.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editedTitle),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    await _repository.renameDocument(doc.id, title.trim());
    await _refreshDocuments();
  }

  Future<void> _renameCurrentDocument() async {
    final id = _currentDocumentId;
    if (id == null) return;
    var editedTitle = _currentDocumentTitle;
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => editedTitle = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editedTitle),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    _currentDocumentTitle = title.trim();
    await _repository.renameDocument(id, _currentDocumentTitle);
    await _refreshDocuments();
  }

  Future<void> _refreshDocuments() async {
    final docs = await _repository.listDocuments();
    if (!mounted) return;
    _documents
      ..clear()
      ..addAll(docs);
    setState(() {});
  }

  Future<void> _deleteDocument(LocalJianpuDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('“${doc.title}” will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (doc.id == _currentDocumentId) await _flushPendingSave();
    await _repository.deleteDocument(doc.id);
    await _refreshDocuments();
    if (doc.id == _currentDocumentId) {
      if (_documents.isEmpty) {
        final fresh = await _repository
            .createDocument(title: 'Untitled Jianpu', runs: const []);
        _documents.add(fresh);
        _openDocument(fresh);
      } else {
        final next = await _repository.getDocument(_documents.first.id);
        if (next != null) _openDocument(next);
      }
    }
  }

  String _formatDocumentDate(DateTime date) {
    final d = date.toLocal();
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _undo() {
    _controller.undo();
    _focusNode.requestFocus();
  }

  void _redo() {
    _controller.redo();
    _focusNode.requestFocus();
  }

  void _changeOctave(int amount) {
    _formatSelection((run) => run.copyWith(octave: run.octave + amount));
  }

  void _changeBeam(int amount) {
    _formatSelection((run) => run.copyWith(
          beam: (run.beam + amount).clamp(0, 16).toInt(),
        ));
  }

  void _toggleItalic() {
    _formatSelection((run) => run.copyWith(italic: !run.italic));
  }

  void _toggleSuperscript() {
    _formatSelection((run) => run.copyWith(superscript: !run.superscript));
  }

  void _toggleSlur() {
    if (!_hasSelection) return;
    final shouldClear = _selectedRuns().any((run) => run.slurId != null);
    final id = 'slur-${++_slurSequence}';
    _formatSelection((run) =>
        shouldClear ? run.copyWith(clearSlur: true) : run.copyWith(slurId: id));
  }

  List<JianpuRun> _selectedRuns() {
    final selection = _controller.selection;
    var offset = 0;
    return _controller.runs.where((run) {
      final start = offset;
      final end = start + run.text.length;
      offset = end;
      return end > selection.start && start < selection.end;
    }).toList();
  }

  void _clearStyles() {
    _formatSelection((run) => run.copyWith(
          octave: 0,
          beam: 0,
          superscript: false,
          italic: false,
          clearSlur: true,
        ));
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) _stopArrowRepeat();
  }

  bool _containsGlobalPoint(GlobalKey key, Offset point) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return rect.contains(point);
  }

  void _handleEditorAreaPointerDown(PointerDownEvent event) {
    if (_containsGlobalPoint(_paperKey, event.position)) {
      // Defer focusing until pointer-up. A drag that scrolls the page must not
      // activate the editor or bring up the on-screen keyboard.
      _paperTapCandidates[event.pointer] = event.position;
      return;
    }
    // Keep the selection available while toolbar controls are being used.
    if (_containsGlobalPoint(_toolbarKey, event.position)) return;
    _focusNode.unfocus();
  }

  void _handleEditorAreaPointerMove(PointerMoveEvent event) {
    final origin = _paperTapCandidates[event.pointer];
    if (origin != null && (event.position - origin).distance > kTouchSlop) {
      _paperTapCandidates.remove(event.pointer);
    }
  }

  void _handleEditorAreaPointerUp(PointerUpEvent event) {
    final origin = _paperTapCandidates.remove(event.pointer);
    if (origin != null) _focusNode.requestFocus();
  }

  void _handleEditorAreaPointerCancel(PointerCancelEvent event) {
    _paperTapCandidates.remove(event.pointer);
  }

  bool _isArrowKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown;

  KeyEventResult _handleRepeatKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) &&
        !HardwareKeyboard.instance.isAltPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          _redo();
        } else {
          _undo();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        _redo();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        _copySelection();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyX) {
        _cutSelection();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        _pasteFromClipboard();
        return KeyEventResult.handled;
      }
    }
    if (event is KeyUpEvent && event.logicalKey == _heldArrowKey) {
      _stopArrowRepeat();
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent || !_isArrowKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    // Leave modified arrows to Shortcuts (word/line navigation and formatting).
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }

    // Handle the initial press ourselves, then synthesize repeats because
    // iPadOS currently sends only KeyDownEvent and KeyUpEvent to Flutter.
    _stopArrowRepeat();
    _heldArrowKey = event.logicalKey;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _preferredVerticalX = null;
    }
    _moveCursorForArrow(event.logicalKey);

    _arrowRepeatInitialTimer = Timer(_arrowRepeatDelay, () {
      if (!_focusNode.hasFocus || _heldArrowKey == null) return;
      _moveCursorForArrow(_heldArrowKey!);
      _arrowRepeatTimer = Timer.periodic(_arrowRepeatInterval, (_) {
        final key = _heldArrowKey;
        if (!_focusNode.hasFocus || key == null) {
          _stopArrowRepeat();
          return;
        }
        _moveCursorForArrow(key);
      });
    });

    return KeyEventResult.handled;
  }

  List<JianpuRun> _runsForRange(int start, int end) {
    final result = <JianpuRun>[];
    var offset = 0;
    for (final run in _controller.runs) {
      final runStart = offset, runEnd = runStart + run.text.length;
      offset = runEnd;
      final from = runStart > start ? runStart : start,
          to = runEnd < end ? runEnd : end;
      if (from < to) {
        result.add(run.copyWith(
            text: run.text.substring(from - runStart, to - runStart)));
      }
    }
    return result;
  }

  String _encodeRuns(List<JianpuRun> runs) => jsonEncode({
        'version': 1,
        'runs': runs
            .map((run) => {
                  'text': run.text,
                  'octave': run.octave,
                  'beam': run.beam,
                  'superscript': run.superscript,
                  'italic': run.italic,
                  'slurId': run.slurId
                })
            .toList(),
      });

  String _encodeHtmlClipboard(List<JianpuRun> runs, String plain) {
    final payload = base64Url.encode(utf8.encode(_encodeRuns(runs)));
    final escaped = plain
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '<!--jianpu-runs:$payload--><pre>$escaped</pre>';
  }

  List<JianpuRun>? _decodeRuns(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          decoded['runs'] is! List) {
        return null;
      }
      final result = <JianpuRun>[];
      for (final item in decoded['runs'] as List) {
        if (item is! Map || item['text'] is! String) return null;
        result.add(JianpuRun(
            text: item['text'] as String,
            octave: item['octave'] is int ? item['octave'] as int : 0,
            beam: item['beam'] is int ? item['beam'] as int : 0,
            superscript: item['superscript'] == true,
            italic: item['italic'] == true,
            slurId:
                item['slurId'] is String ? item['slurId'] as String : null));
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _copySelection() async {
    final sel = _controller.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final runs = _runsForRange(sel.start, sel.end),
        plain = runs.map((r) => r.text).join();
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      await Clipboard.setData(ClipboardData(text: plain));
      return;
    }
    final item = DataWriterItem();
    item.add(_jianpuClipboardFormat(_encodeRuns(runs)));
    // Keep a standard HTML representation as a second rich-data path. Some
    // platform clipboards normalize custom UTIs, while preserving public.html.
    item.add(Formats.htmlText(_encodeHtmlClipboard(runs, plain)));
    item.add(Formats.plainText(plain));
    await clipboard.write([item]);
  }

  Future<void> _cutSelection() async {
    final sel = _controller.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    await _copySelection();
    _controller.replaceRangeWithRuns(sel.start, sel.end, const []);
    _focusNode.requestFocus();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) _insertPlainText(data!.text!);
      return;
    }
    try {
      final reader = await clipboard.read();
      if (reader.canProvide(_jianpuClipboardFormat)) {
        final payload = await reader.readValue(_jianpuClipboardFormat);
        final runs = payload == null ? null : _decodeRuns(payload);
        if (runs != null) {
          _insertRichRuns(runs);
          return;
        }
      }
      // The HTML representation carries the same private Jianpu payload.
      // This is a fallback for platforms that do not round-trip custom UTIs.
      if (reader.canProvide(Formats.htmlText)) {
        final html = await reader.readValue(Formats.htmlText);
        if (html != null) {
          final match =
              RegExp(r'<!--jianpu-runs:([A-Za-z0-9_=-]+)-->').firstMatch(html);
          if (match != null) {
            final encoded = base64Url.normalize(match.group(1)!);
            final payload = utf8.decode(base64Url.decode(encoded));
            final runs = _decodeRuns(payload);
            if (runs != null) {
              _insertRichRuns(runs);
              return;
            }
          }
        }
      }
      if (reader.canProvide(Formats.plainText)) {
        final plain = await reader.readValue(Formats.plainText);
        if (plain != null) _insertPlainText(plain);
      }
    } catch (_) {/* Preserve the document if clipboard access is denied. */}
  }

  void _insertPlainText(String text) =>
      _insertRichRuns(text.isEmpty ? const [] : [JianpuRun(text: text)]);

  void _insertRichRuns(List<JianpuRun> sourceRuns) {
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final slurIds = <String, String>{};
    final runs = sourceRuns.map((run) {
      final oldId = run.slurId;
      if (oldId == null) return run;
      final newId = slurIds.putIfAbsent(oldId, () => 'slur-${++_slurSequence}');
      return run.copyWith(slurId: newId);
    }).toList();
    _controller.replaceRangeWithRuns(sel.start, sel.end, runs);
    _focusNode.requestFocus();
  }

  void _stopArrowRepeat() {
    _arrowRepeatInitialTimer?.cancel();
    _arrowRepeatInitialTimer = null;
    _arrowRepeatTimer?.cancel();
    _arrowRepeatTimer = null;
    _heldArrowKey = null;
  }

  void _moveCursorForArrow(LogicalKeyboardKey key) {
    final selection = _controller.selection;
    if (!selection.isValid) return;
    final text = _controller.text;
    final caret = selection.extentOffset;
    var next = caret;

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final left = key == LogicalKeyboardKey.arrowLeft;
      if (!HardwareKeyboard.instance.isShiftPressed && !selection.isCollapsed) {
        next = left ? selection.start : selection.end;
      } else {
        next = (caret + (left ? -1 : 1)).clamp(0, text.length).toInt();
      }
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final editable = _findRenderEditable();
      if (editable == null) return;

      // Use the rendered caret geometry rather than newline characters. This
      // follows visual lines, including soft wraps, and keeps the preferred
      // horizontal position stable when moving through short lines.
      final caretRect =
          editable.getLocalRectForCaret(TextPosition(offset: caret));
      _preferredVerticalX ??= caretRect.center.dx;
      final direction = key == LogicalKeyboardKey.arrowUp ? -1.0 : 1.0;
      final targetPoint = Offset(
        _preferredVerticalX!,
        caretRect.center.dy + direction * caretRect.height,
      );
      // RenderEditable.getPositionForPoint expects a GLOBAL point, while
      // getLocalRectForCaret returns local coordinates. Convert explicitly;
      // passing targetPoint directly makes globalToLocal offset it again,
      // which incorrectly sends vertical navigation toward the first line.
      next = editable
          .getPositionForPoint(editable.localToGlobal(targetPoint))
          .offset;
      next = next.clamp(0, text.length).toInt();
      if (next == caret) return;
    } else {
      return;
    }

    if (HardwareKeyboard.instance.isShiftPressed) {
      final anchor = selection.isCollapsed ? caret : selection.baseOffset;
      _controller.selection =
          TextSelection(baseOffset: anchor, extentOffset: next);
    } else {
      _controller.selection = TextSelection.collapsed(offset: next);
    }
  }

  RenderEditable? _findRenderEditable() {
    final root = _editorFieldKey.currentContext?.findRenderObject();
    if (root == null) return null;

    RenderEditable? result;
    void visit(RenderObject child) {
      if (child is RenderEditable) {
        result = child;
        return;
      }
      child.visitChildren(visit);
    }

    visit(root);
    return result;
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.escape): const DismissIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            const SelectAllTextIntent(SelectionChangedCause.keyboard),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            const SelectAllTextIntent(SelectionChangedCause.keyboard),
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.octaveUp)
                : const ExtendSelectionToLineBreakIntent(
                    forward: false, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.octaveDown)
                : const ExtendSelectionToLineBreakIntent(
                    forward: true, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.beamUp)
                : const ExtendSelectionToNextWordBoundaryIntent(
                    forward: false, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.beamDown)
                : const ExtendSelectionToNextWordBoundaryIntent(
                    forward: true, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.octaveUp)
                : const ExtendSelectionToLineBreakIntent(
                    forward: false, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.octaveDown)
                : const ExtendSelectionToLineBreakIntent(
                    forward: true, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.beamUp)
                : const ExtendSelectionToLineBreakIntent(
                    forward: false, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
            _hasSelection
                ? const EditorFormatIntent(EditorFormatCommand.beamDown)
                : const ExtendSelectionToLineBreakIntent(
                    forward: true, collapseSelection: true),
        if (_hasSelection) ...{
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              const EditorFormatIntent(EditorFormatCommand.superscript),
          const SingleActivator(LogicalKeyboardKey.keyI, control: true):
              const EditorFormatIntent(EditorFormatCommand.italic),
          const SingleActivator(LogicalKeyboardKey.keyD, control: true):
              const EditorFormatIntent(EditorFormatCommand.clear),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              const EditorFormatIntent(EditorFormatCommand.superscript),
          const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
              const EditorFormatIntent(EditorFormatCommand.italic),
          const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
              const EditorFormatIntent(EditorFormatCommand.clear),
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft,
                control: true, shift: true):
            const ExtendSelectionToNextWordBoundaryIntent(
                forward: false, collapseSelection: false),
        const SingleActivator(LogicalKeyboardKey.arrowRight,
                control: true, shift: true):
            const ExtendSelectionToNextWordBoundaryIntent(
                forward: true, collapseSelection: false),
        const SingleActivator(LogicalKeyboardKey.arrowUp,
                control: true, shift: true):
            const ExtendSelectionToLineBreakIntent(
                forward: false, collapseSelection: false),
        const SingleActivator(LogicalKeyboardKey.arrowDown,
                control: true, shift: true):
            const ExtendSelectionToLineBreakIntent(
                forward: true, collapseSelection: false),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            const ExtendSelectionToNextWordBoundaryIntent(
                forward: false, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            const ExtendSelectionToNextWordBoundaryIntent(
                forward: true, collapseSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft,
                alt: true, shift: true):
            const ExtendSelectionToNextWordBoundaryIntent(
                forward: false, collapseSelection: false),
        const SingleActivator(LogicalKeyboardKey.arrowRight,
                alt: true, shift: true):
            const ExtendSelectionToNextWordBoundaryIntent(
                forward: true, collapseSelection: false),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
            onInvoke: (_) {
              if (_hasSelection) {
                _toggleSlur();
              } else {
                _selectAll();
              }
              return null;
            },
          ),
          EditorFormatIntent: CallbackAction<EditorFormatIntent>(
            onInvoke: (intent) {
              switch (intent.command) {
                case EditorFormatCommand.octaveUp:
                  _changeOctave(1);
                  break;
                case EditorFormatCommand.octaveDown:
                  _changeOctave(-1);
                  break;
                case EditorFormatCommand.beamUp:
                  _changeBeam(1);
                  break;
                case EditorFormatCommand.beamDown:
                  _changeBeam(-1);
                  break;
                case EditorFormatCommand.superscript:
                  _toggleSuperscript();
                  break;
                case EditorFormatCommand.italic:
                  _toggleItalic();
                  break;
                case EditorFormatCommand.clear:
                  _clearStyles();
                  break;
              }
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handleEditorAreaPointerDown,
          onPointerMove: _handleEditorAreaPointerMove,
          onPointerUp: _handleEditorAreaPointerUp,
          onPointerCancel: _handleEditorAreaPointerCancel,
          child: Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(child: _buildDocumentDrawer()),
            appBar: AppBar(
              centerTitle: false,
              title: GestureDetector(
                onTap: _isLoadingDocuments ? null : _renameCurrentDocument,
                child: Text(_currentDocumentTitle),
              ),
              actions: [
                IconButton(
                  tooltip: 'Editing test instructions',
                  onPressed: () => setState(() => _showHelp = !_showHelp),
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      KeyedSubtree(
                        key: _toolbarKey,
                        child: _buildToolbar(context),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const basePageWidth = 600.0;
                            final notationStyle = GoogleFonts.lxgwWenKaiMonoTc(
                              fontSize: 18,
                              color: const Color(0xFF202124),
                            );
                            final textPainter = TextPainter(
                              text: _controller.buildTextSpan(
                                context: context,
                                style: notationStyle,
                                withComposing: false,
                              ),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                              textWidthBasis: TextWidthBasis.longestLine,
                            )..layout(maxWidth: double.infinity);

                            // Keep every line on one line. Expand the page
                            // until both the text width and height fit inside
                            // the printable area, then derive its height
                            // from the A4 ratio.
                            const horizontalContentPadding = 42.0;
                            const verticalContentPadding = 48.0;
                            // Use intrinsic width rather than the laid-out
                            // paragraph width, with a little extra room for
                            // EditableText's caret and glyph metrics. This
                            // prevents the field reaching its wrap threshold
                            // before the paper has expanded.
                            final requiredTextWidth =
                                textPainter.maxIntrinsicWidth + 24.0;
                            final lineMetrics = textPainter.computeLineMetrics();
                            final measuredTextHeight = lineMetrics.fold<double>(
                              0,
                              (total, line) => total + line.height,
                            );
                            final requiredTextHeight = math.max(
                              textPainter.height,
                              measuredTextHeight,
                            );
                            final requiredWidth = requiredTextWidth +
                                horizontalContentPadding * 2;
                            final requiredHeight = requiredTextHeight +
                                verticalContentPadding * 2;
                            final pageWidth = math.max(
                              basePageWidth,
                              math.max(
                                  requiredWidth, requiredHeight * 210 / 297),
                            );
                            final pageHeight = pageWidth * 297 / 210;
                            return SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width:
                                      math.max(pageWidth, constraints.maxWidth),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      margin: const EdgeInsets.all(20),
                                      key: _paperKey,
                                      width: pageWidth,
                                      height: pageHeight,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x18000000),
                                            blurRadius: 18,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          textSelectionTheme:
                                              const TextSelectionThemeData(
                                            selectionHandleColor:
                                                Color(0xFF315E9E),
                                          ),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          alignment: Alignment.topLeft,
                                          clipBehavior: Clip.none,
                                          children: [
                                            TextField(
                                              key: _editorFieldKey,
                                              controller: _controller,
                                              focusNode: _focusNode,
                                              style: notationStyle,
                                              cursorColor:
                                                  const Color(0xFF315E9E),
                                              keyboardType:
                                                  TextInputType.multiline,
                                              maxLines: null,
                                              expands: true,
                                              // The paper itself grows to fit
                                              // the complete document. The
                                              // editable surface must never
                                              // become an independently
                                              // scrollable viewport.
                                              scrollPhysics:
                                                  const NeverScrollableScrollPhysics(),
                                              autofocus: false,
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              enableInteractiveSelection: true,
                                              contextMenuBuilder:
                                                  (context, editableTextState) {
                                                final items = editableTextState
                                                    .contextMenuButtonItems;
                                                for (var i = 0;
                                                    i < items.length;
                                                    i++) {
                                                  final item = items[i];
                                                  switch (item.type) {
                                                    case ContextMenuButtonType
                                                          .copy:
                                                      items[i] = item.copyWith(
                                                          onPressed: () {
                                                        ContextMenuController
                                                            .removeAny();
                                                        unawaited(
                                                            _copySelection());
                                                      });
                                                      break;
                                                    case ContextMenuButtonType
                                                          .cut:
                                                      items[i] = item.copyWith(
                                                          onPressed: () {
                                                        ContextMenuController
                                                            .removeAny();
                                                        unawaited(
                                                            _cutSelection());
                                                      });
                                                      break;
                                                    case ContextMenuButtonType
                                                          .paste:
                                                      items[i] = item.copyWith(
                                                          onPressed: () {
                                                        ContextMenuController
                                                            .removeAny();
                                                        unawaited(
                                                            _pasteFromClipboard());
                                                      });
                                                      break;
                                                    default:
                                                      break;
                                                  }
                                                }
                                                return AdaptiveTextSelectionToolbar
                                                    .buttonItems(
                                                  anchors: editableTextState
                                                      .contextMenuAnchors,
                                                  buttonItems: items,
                                                );
                                              },
                                              textCapitalization:
                                                  TextCapitalization.none,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  vertical:
                                                      verticalContentPadding,
                                                  horizontal:
                                                      horizontalContentPadding,
                                                ),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                            Positioned.fill(
                                              child: JianpuNotationOverlay(
                                                controller: _controller,
                                                textFieldKey: _editorFieldKey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentDrawer() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "JP Typewriter",
              style: GoogleFonts.lxgwWenKaiMonoTc(fontSize: 22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isLoadingDocuments ? null : _createDocument,
                  label: const Text("New"),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingDocuments
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      final selected = doc.id == _currentDocumentId;
                      return ListTile(
                        selected: selected,
                        title: Text(doc.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_formatDocumentDate(doc.updatedAt)),
                        onTap: () async {
                          if (!selected) {
                            await _flushPendingSave();
                            if (!mounted) return;
                            final latest =
                                await _repository.getDocument(doc.id);
                            if (latest != null) _openDocument(latest);
                          }
                          if (!mounted) return;
                          _scaffoldKey.currentState?.closeDrawer();
                        },
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Document actions',
                          onSelected: (action) {
                            if (action == 'rename') _renameDocument(doc);
                            if (action == 'delete') _deleteDocument(doc);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                                value: 'rename', child: Text('Rename')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
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

  Widget _buildToolbar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Undo (Ctrl/Cmd+Z)',
                  onPressed: _controller.canUndo ? _undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Redo (Ctrl/Cmd+Shift+Z)',
                  onPressed: _controller.canRedo ? _redo : null,
                  icon: const Icon(Icons.redo),
                ),
                _tool(Icons.format_italic, 'Toggle italic (Ctrl/Cmd+I)',
                    _toggleItalic),
                _tool(Icons.superscript, 'Toggle superscript (Ctrl/Cmd+S)',
                    _toggleSuperscript),
                _tool(Icons.arrow_back, 'Increase beam (Ctrl/Cmd+Left)',
                    () => _changeBeam(1)),
                _tool(Icons.arrow_forward, 'Decrease beam (Ctrl/Cmd+Right)',
                    () => _changeBeam(-1)),
                _tool(Icons.arrow_upward, 'Raise octave (Ctrl/Cmd+Up)',
                    () => _changeOctave(1)),
                _tool(Icons.arrow_downward, 'Lower octave (Ctrl/Cmd+Down)',
                    () => _changeOctave(-1)),
                _tool(Icons.format_clear, 'Clear formatting (Ctrl/Cmd+D)',
                    _clearStyles),
                _tool(Icons.looks, 'Toggle slur (Ctrl/Cmd+A)', _toggleSlur),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
