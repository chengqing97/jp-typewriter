import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/jianpu_document.dart';
import 'octave_dot_painter.dart';

/// First editing-engine spike: use Flutter's single EditableText surface,
/// rather than one widget per note or a webview contenteditable element.
/// Keeps a single editable text surface while rendering per-range Jianpu styles.
class JianpuEditingController extends TextEditingController
    implements JianpuNotationSource {
  JianpuEditingController({required String text}) : super(text: text) {
    _lastText = text;
    _runs = text.isEmpty ? <JianpuRun>[] : <JianpuRun>[JianpuRun(text: text)];
    addListener(_reconcileTextChanges);
  }

  late String _lastText;
  late List<JianpuRun> _runs;

  @override
  List<JianpuRun> get runs => List.unmodifiable(_runs);

  void formatRange(
      int start, int end, JianpuRun Function(JianpuRun) transform) {
    if (start < 0 || end > text.length || start >= end) return;
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
    if (current == _lastText) return;

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
    final lengthDelta = current.length - _lastText.length;
    final selection = value.selection;
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
  bool _showHelp = true;
  int _slurSequence = 0;

  static const _sample = '4 4 5 5 | 6 6 5 -\n'
      '4 4 3 3 | 2 2 1 -\n'
      '1 1 2 3 | 3 2 2 -\n'
      '1 1 2 3 | 3 2 2 -';

  @override
  void initState() {
    super.initState();
    _controller = JianpuEditingController(text: _sample);
    _focusNode = FocusNode(
      debugLabel: 'Jianpu editor',
      onKeyEvent: _handleRepeatKey,
    );
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
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
    if (mounted) setState(() {});
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

  KeyEventResult _handleRepeatKey(FocusNode node, KeyEvent event) {
    if (event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final selection = _controller.selection;
    if (!selection.isValid) return KeyEventResult.ignored;
    final text = _controller.text;
    var caret = selection.extentOffset;
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
      final previousBreak = caret > 0 ? text.lastIndexOf('\n', caret - 1) : -1;
      final lineStart = previousBreak + 1;
      final lineEndFound = text.indexOf('\n', caret);
      final lineEnd = lineEndFound < 0 ? text.length : lineEndFound;
      final column = caret - lineStart;
      if (key == LogicalKeyboardKey.arrowUp) {
        if (lineStart == 0) return KeyEventResult.ignored;
        final previousEnd = lineStart - 1;
        final previousStart =
            (previousEnd > 0 ? text.lastIndexOf('\n', previousEnd - 1) + 1 : 0);
        next =
            (previousStart + column).clamp(previousStart, previousEnd).toInt();
      } else {
        if (lineEnd == text.length) return KeyEventResult.ignored;
        final nextStart = lineEnd + 1;
        final nextEndFound = text.indexOf('\n', nextStart);
        final nextEnd = nextEndFound < 0 ? text.length : nextEndFound;
        next = (nextStart + column).clamp(nextStart, nextEnd).toInt();
      }
    } else {
      return KeyEventResult.ignored;
    }

    if (HardwareKeyboard.instance.isShiftPressed) {
      final anchor = selection.isCollapsed ? caret : selection.baseOffset;
      _controller.selection =
          TextSelection(baseOffset: anchor, extentOffset: next);
    } else {
      _controller.selection = TextSelection.collapsed(offset: next);
    }
    return KeyEventResult.handled;
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
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Jianpu Typewriter'),
            actions: [
              IconButton(
                tooltip: 'Editing test instructions',
                onPressed: () => setState(() => _showHelp = !_showHelp),
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildToolbar(context),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pageWidth =
                          constraints.maxWidth.clamp(280.0, 760.0).toDouble();
                      final pageHeight = pageWidth * 297 / 210;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Container(
                            width: pageWidth,
                            constraints: BoxConstraints(
                              minHeight: pageHeight,
                            ),
                            padding: const EdgeInsets.fromLTRB(42, 48, 42, 48),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Untitled Jianpu',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    textSelectionTheme:
                                        const TextSelectionThemeData(
                                      selectionHandleColor: Color(0xFF315E9E),
                                    ),
                                  ),
                                  child: CustomPaint(
                                    foregroundPainter: OctaveDotPainter(
                                      controller: _controller,
                                      baseStyle: GoogleFonts.lxgwWenKaiMonoTc(
                                        fontSize: 23,
                                        height: 2.0,
                                        color: const Color(0xFF202124),
                                      ),
                                      textDirection: Directionality.of(context),
                                      textScaler:
                                          MediaQuery.textScalerOf(context),
                                    ),
                                    child: TextField(
                                        controller: _controller,
                                        focusNode: _focusNode,
                                        style: GoogleFonts.lxgwWenKaiMonoTc(
                                          fontSize: 23,
                                          height: 2.0,
                                          color: const Color(0xFF202124),
                                        ),
                                        cursorColor: const Color(0xFF315E9E),
                                        selectionColor: const Color(0x55315E9E),
                                        keyboardType: TextInputType.multiline,
                                        maxLines: null,
                                        autofocus: false,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        enableInteractiveSelection: true,
                                        textCapitalization:
                                            TextCapitalization.none,
                                        decoration: const InputDecoration.collapsed(
                                          hintText: '',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_showHelp) ...[
                                  const SizedBox(height: 32),
                                  const Divider(),
                                  Text(
                                    'Editing engine prototype',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Connect a physical keyboard and test '
                                    'ArrowUp / ArrowDown across wrapped lines, '
                                    'Home / End, Shift + arrows, selection, '
                                    'and text insertion.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildStatusBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _tool(Icons.format_italic, 'Toggle italic (Ctrl/Cmd+I)',
                _toggleItalic),
            _tool(Icons.text_fields, 'Toggle superscript (Ctrl/Cmd+S)',
                _toggleSuperscript),
            _tool(Icons.horizontal_rule, 'Increase beam (Ctrl/Cmd+Left)',
                () => _changeBeam(1)),
            _tool(Icons.remove, 'Decrease beam (Ctrl/Cmd+Right)',
                () => _changeBeam(-1)),
            _tool(Icons.arrow_upward, 'Raise octave (Ctrl/Cmd+Up)',
                () => _changeOctave(1)),
            _tool(Icons.arrow_downward, 'Lower octave (Ctrl/Cmd+Down)',
                () => _changeOctave(-1)),
            _tool(Icons.format_clear, 'Clear formatting (Ctrl/Cmd+D)',
                _clearStyles),
            _tool(Icons.architecture, 'Toggle slur (Ctrl/Cmd+A)', _toggleSlur),
          ],
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

  Widget _buildStatusBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: Theme.of(context).colorScheme.surface,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final offset =
              value.selection.isValid ? value.selection.extentOffset : 0;
          return Text(
            'Characters: ${value.text.length}    Cursor: $offset',
            style: Theme.of(context).textTheme.labelSmall,
          );
        },
      ),
    );
  }
}
