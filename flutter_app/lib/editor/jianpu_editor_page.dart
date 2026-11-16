import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/jianpu_document.dart';

/// First editing-engine spike: use Flutter's single EditableText surface,
/// rather than one widget per note or a webview contenteditable element.
/// Keeps a single editable text surface while rendering per-range Jianpu styles.
class JianpuEditingController extends TextEditingController {
  JianpuEditingController({required String text}) : super(text: text) {
    _lastText = text;
    _runs = text.isEmpty ? <JianpuRun>[] : <JianpuRun>[JianpuRun(text: text)];
    addListener(_reconcileTextChanges);
  }

  late String _lastText;
  late List<JianpuRun> _runs;

  void formatRange(int start, int end, JianpuRun Function(JianpuRun) transform) {
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

      final localStart = (start - runStart).clamp(0, run.text.length);
      final localEnd = (end - runStart).clamp(0, run.text.length);
      if (localStart > 0) {
        _appendRun(updated, run.copyWith(text: run.text.substring(0, localStart)));
      }
      if (localEnd > localStart) {
        _appendRun(
          updated,
          transform(run.copyWith(text: run.text.substring(localStart, localEnd))),
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
        target[target.length - 1] = previous.copyWith(text: previous.text + run.text);
        return;
      }
    }
    target.add(run);
  }

  void _reconcileTextChanges() {
    final current = text;
    if (current == _lastText) return;

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

    final oldEnd = _lastText.length - suffix;
    final inserted = current.substring(prefix, current.length - suffix);
    final updated = <JianpuRun>[];
    var offset = 0;

    for (final run in _runs) {
      final runStart = offset;
      final runEnd = offset + run.text.length;
      offset = runEnd;

      if (runStart < prefix) {
        final keepEnd = (runEnd < prefix ? runEnd : prefix);
        if (keepEnd > runStart) {
          _appendRun(updated, run.copyWith(
            text: run.text.substring(0, keepEnd - runStart),
          ));
        }
      }
      if (runEnd > oldEnd) {
        final keepStart = runStart > oldEnd ? runStart : oldEnd;
        if (runEnd > keepStart) {
          _appendRun(updated, run.copyWith(
            text: run.text.substring(keepStart - runStart),
          ));
        }
      }
    }

    // Inserted text starts unformatted; existing formatting outside the edit survives.
    final before = <JianpuRun>[];
    final after = <JianpuRun>[];
    var newOffset = 0;
    for (final run in updated) {
      final runEnd = newOffset + run.text.length;
      if (runEnd <= prefix) {
        _appendRun(before, run);
      } else {
        _appendRun(after, run);
      }
      newOffset = runEnd;
    }
    _runs = <JianpuRun>[];
    for (final run in before) {
      _appendRun(_runs, run);
    }
    if (inserted.isNotEmpty) {
      _appendRun(_runs, JianpuRun(text: inserted));
    }
    for (final run in after) {
      _appendRun(_runs, run);
    }
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
      final decorations = <TextDecoration>[];
      if (run.beam > 0 || run.octave < 0) {
        decorations.add(TextDecoration.underline);
      }
      if (run.octave > 0) decorations.add(TextDecoration.overline);

      spans.add(TextSpan(
        text: run.text,
        style: TextStyle(
          fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
          fontSize: run.superscript ? 15 : null,
          decoration: decorations.isEmpty
              ? TextDecoration.none
              : TextDecoration.combine(decorations),
          decorationThickness: run.beam > 1 ? 2.0 : 1.0,
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

class JianpuEditorPage extends StatefulWidget {
  const JianpuEditorPage({super.key});

  @override
  State<JianpuEditorPage> createState() => _JianpuEditorPageState();
}

class _JianpuEditorPageState extends State<JianpuEditorPage> {
  late final JianpuEditingController _controller;
  late final FocusNode _focusNode;
  bool _showHelp = true;

  static const _sample = '4 4 5 5 | 6 6 5 -\n'
      '4 4 3 3 | 2 2 1 -\n'
      '1 1 2 3 | 3 2 2 -\n'
      '1 1 2 3 | 3 2 2 -';

  @override
  void initState() {
    super.initState();
    _controller = JianpuEditingController(text: _sample);
    _focusNode = FocusNode(debugLabel: 'Jianpu editor');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _insert(String value) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : start;
    final text = _controller.text.replaceRange(start, end, value);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    _focusNode.requestFocus();
  }

  void _formatSelection(JianpuRun Function(JianpuRun) transform) {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    _controller.formatRange(selection.start, selection.end, transform);
    _focusNode.requestFocus();
  }

  void _changeOctave(int amount) {
    _formatSelection((run) => run.copyWith(
          octave: (run.octave + amount).clamp(-2, 2).toInt(),
        ));
  }

  void _toggleItalic() {
    _formatSelection((run) => run.copyWith(italic: !run.italic));
  }

  void _toggleSuperscript() {
    _formatSelection(
        (run) => run.copyWith(superscript: !run.superscript));
  }

  void _cycleBeam() {
    _formatSelection((run) => run.copyWith(beam: (run.beam + 1) % 4));
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
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.keyA, control: true):
            SelectAllTextIntent(SelectionChangedCause.keyboard),
        SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            SelectAllTextIntent(SelectionChangedCause.keyboard),

        // Word-wise navigation on Android/Windows/Linux keyboards.
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: false,
          collapseSelection: true,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: true,
          collapseSelection: true,
        ),
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, shift: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: false,
          collapseSelection: false,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true, shift: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: true,
          collapseSelection: false,
        ),

        // Ctrl + Up/Down moves to the beginning/end of the current line.
        SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
            ExtendSelectionToLineBreakIntent(
          forward: false,
          collapseSelection: true,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
            ExtendSelectionToLineBreakIntent(
          forward: true,
          collapseSelection: true,
        ),
        SingleActivator(LogicalKeyboardKey.arrowUp, control: true, shift: true):
            ExtendSelectionToLineBreakIntent(
          forward: false,
          collapseSelection: false,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown, control: true, shift: true):
            ExtendSelectionToLineBreakIntent(
          forward: true,
          collapseSelection: false,
        ),

        // Option + Left/Right is the usual word-navigation shortcut on iPad.
        SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: false,
          collapseSelection: true,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: true,
          collapseSelection: true,
        ),
        SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true, shift: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: false,
          collapseSelection: false,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight, alt: true, shift: true):
            ExtendSelectionToNextWordBoundaryIntent(
          forward: true,
          collapseSelection: false,
        ),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
            onInvoke: (_) {
              _selectAll();
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
                      final pageWidth = constraints.maxWidth
                          .clamp(280.0, 760.0)
                          .toDouble();
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
                                EditableText(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 23,
                                    height: 2.0,
                                    color: Color(0xFF202124),
                                  ),
                                  cursorColor: const Color(0xFF315E9E),
                                  backgroundCursorColor: Colors.grey,
                                  selectionColor:
                                      const Color(0x55315E9E),
                                  keyboardType: TextInputType.multiline,
                                  maxLines: null,
                                  expands: false,
                                  autofocus: false,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  selectionControls:
                                      materialTextSelectionControls,
                                  textCapitalization:
                                      TextCapitalization.none,
                                  onChanged: (_) => setState(() {}),
                                ),
                                if (_showHelp) ...[
                                  const SizedBox(height: 32),
                                  const Divider(),
                                  Text(
                                    'Editing engine prototype',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
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
            _tool(Icons.format_italic, 'Toggle italic on selection', _toggleItalic),
            _tool(Icons.text_fields, 'Toggle superscript on selection', _toggleSuperscript),
            _tool(Icons.horizontal_rule, 'Cycle beam level on selection', _cycleBeam),
            _tool(Icons.arrow_upward, 'Raise octave on selection', () => _changeOctave(1)),
            _tool(Icons.arrow_downward, 'Lower octave on selection', () => _changeOctave(-1)),
            for (final digit in ['1', '2', '3', '4', '5', '6', '7'])
              TextButton(
                onPressed: () => _insert(digit),
                child: Text(digit, style: const TextStyle(fontSize: 18)),
              ),
            _tool(Icons.space_bar, 'Insert space', () => _insert(' ')),
            _tool(Icons.keyboard_return, 'New line', () => _insert('\n')),
            _tool(Icons.select_all, 'Select all', _selectAll),
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
          final offset = value.selection.isValid
              ? value.selection.extentOffset
              : 0;
          return Text(
            'Characters: ${value.text.length}    Cursor: $offset',
            style: Theme.of(context).textTheme.labelSmall,
          );
        },
      ),
    );
  }
}
