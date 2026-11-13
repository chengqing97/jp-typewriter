import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// First editing-engine spike: use Flutter's single EditableText surface,
/// rather than one widget per note or a webview contenteditable element.
class JianpuEditorPage extends StatefulWidget {
  const JianpuEditorPage({super.key});

  @override
  State<JianpuEditorPage> createState() => _JianpuEditorPageState();
}

class _JianpuEditorPageState extends State<JianpuEditorPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _showHelp = true;

  static const _sample = '4 4 5 5 | 6 6 5 -\n'
      '4 4 3 3 | 2 2 1 -\n'
      '1 1 2 3 | 3 2 2 -\n'
      '1 1 2 3 | 3 2 2 -';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _sample);
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
            _tool(Icons.format_bold, 'Bold (test)', () {}),
            _tool(Icons.format_italic, 'Italic (test)', () {}),
            _tool(Icons.arrow_upward, 'Octave up (next phase)', () {}),
            _tool(Icons.arrow_downward, 'Octave down (next phase)', () {}),
            _tool(Icons.undo, 'Undo', () {
              _controller.undo();
              _focusNode.requestFocus();
            }),
            _tool(Icons.redo, 'Redo', () {
              _controller.redo();
              _focusNode.requestFocus();
            }),
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
