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
import 'jianpu_editing_controller.dart';
import 'jianpu_clipboard_codec.dart';
import 'jianpu_document_drawer.dart';
import 'jianpu_editor_toolbar.dart';


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
  double? _renderedIntrinsicWidth;
  double? _renderedIntrinsicHeight;
  String? _lastIntrinsicMeasurementText;
  bool _intrinsicMeasurementScheduled = false;

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

  void _scheduleIntrinsicMeasurement() {
    final text = _controller.text;
    if (_intrinsicMeasurementScheduled ||
        _lastIntrinsicMeasurementText == text) {
      return;
    }

    _intrinsicMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _intrinsicMeasurementScheduled = false;
      if (!mounted || text != _controller.text) return;

      // Measure after EditableText has received the controller update. Doing
      // this during the controller notification can read RenderEditable's
      // previous text because its listener runs later in the same dispatch.
      final editable = _findRenderEditable();
      if (editable == null || !editable.attached) return;

      final width = editable.getMaxIntrinsicWidth(double.infinity);
      final height = editable.getMaxIntrinsicHeight(double.infinity);
      if (!width.isFinite || !height.isFinite) return;

      _lastIntrinsicMeasurementText = text;
      if (_renderedIntrinsicWidth == width &&
          _renderedIntrinsicHeight == height) {
        return;
      }

      setState(() {
        _renderedIntrinsicWidth = width;
        _renderedIntrinsicHeight = height;
      });
    });
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _lastIntrinsicMeasurementText = null;
    _scheduleIntrinsicMeasurement();
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

  void _insertToolbarSymbol(String symbol) {
    _insertPlainText(symbol);
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
    item.add(JianpuClipboardCodec.format(JianpuClipboardCodec.encodeRuns(runs)));
    // Keep a standard HTML representation as a second rich-data path. Some
    // platform clipboards normalize custom UTIs, while preserving public.html.
    item.add(Formats.htmlText(JianpuClipboardCodec.encodeHtmlClipboard(runs, plain)));
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
      if (reader.canProvide(JianpuClipboardCodec.format)) {
        final payload = await reader.readValue(JianpuClipboardCodec.format);
        final runs = payload == null ? null : JianpuClipboardCodec.decodeRuns(payload);
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
            final runs = JianpuClipboardCodec.decodeRuns(payload);
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
                            // Prefer the editable's own intrinsic
                            // measurement so the page width follows the
                            // exact text layout used by the TextField. On the
                            // first frame, before RenderEditable exists, use
                            // the matching TextPainter measurement.
                            _scheduleIntrinsicMeasurement();
                            final requiredTextWidth = _renderedIntrinsicWidth ??
                                textPainter.maxIntrinsicWidth;
                            final requiredTextHeight =
                                _renderedIntrinsicHeight ?? textPainter.height;
                            final requiredWidth = requiredTextWidth +
                                horizontalContentPadding * 2;
                            final requiredHeight =
                                requiredTextHeight + verticalContentPadding * 2;
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
    return JianpuDocumentDrawer(
      documents: _documents,
      currentDocumentId: _currentDocumentId,
      isLoading: _isLoadingDocuments,
      onCreate: _createDocument,
      onOpen: (doc) async {
        if (doc.id != _currentDocumentId) {
          await _flushPendingSave();
          if (!mounted) return;
          final latest = await _repository.getDocument(doc.id);
          if (latest != null) _openDocument(latest);
        }
        if (mounted) _scaffoldKey.currentState?.closeDrawer();
      },
      onRename: _renameDocument,
      onDelete: _deleteDocument,
      formatDate: _formatDocumentDate,
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return JianpuEditorToolbar(
      canUndo: _controller.canUndo,
      canRedo: _controller.canRedo,
      onUndo: _undo,
      onRedo: _redo,
      onToggleItalic: _toggleItalic,
      onToggleSuperscript: _toggleSuperscript,
      onIncreaseBeam: () => _changeBeam(1),
      onDecreaseBeam: () => _changeBeam(-1),
      onRaiseOctave: () => _changeOctave(1),
      onLowerOctave: () => _changeOctave(-1),
      onClearFormatting: _clearStyles,
      onToggleSlur: _toggleSlur,
      onInsertSymbol: _insertToolbarSymbol,
    );
  }

}
