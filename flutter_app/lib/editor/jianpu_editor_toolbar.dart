import 'package:material_ui/material_ui.dart';

class JianpuEditorToolbar extends StatelessWidget {
  const JianpuEditorToolbar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleItalic,
    required this.onToggleSuperscript,
    required this.onIncreaseBeam,
    required this.onDecreaseBeam,
    required this.onRaiseOctave,
    required this.onLowerOctave,
    required this.onClearFormatting,
    required this.onToggleSlur,
    required this.onInsertSymbol,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleSuperscript;
  final VoidCallback onIncreaseBeam;
  final VoidCallback onDecreaseBeam;
  final VoidCallback onRaiseOctave;
  final VoidCallback onLowerOctave;
  final VoidCallback onClearFormatting;
  final VoidCallback onToggleSlur;
  final ValueChanged<String> onInsertSymbol;

  @override
  Widget build(BuildContext context) {
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
                  onPressed: canUndo ? onUndo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Redo (Ctrl/Cmd+Shift+Z)',
                  onPressed: canRedo ? onRedo : null,
                  icon: const Icon(Icons.redo),
                ),
                _tool(Icons.format_italic, 'Toggle italic (Ctrl/Cmd+I)', onToggleItalic),
                _tool(Icons.superscript, 'Toggle superscript (Ctrl/Cmd+S)', onToggleSuperscript),
                _tool(Icons.arrow_back, 'Increase beam (Ctrl/Cmd+Left)', onIncreaseBeam),
                _tool(Icons.arrow_forward, 'Decrease beam (Ctrl/Cmd+Right)', onDecreaseBeam),
                _tool(Icons.arrow_upward, 'Raise octave (Ctrl/Cmd+Up)', onRaiseOctave),
                _tool(Icons.arrow_downward, 'Lower octave (Ctrl/Cmd+Down)', onLowerOctave),
                _tool(Icons.format_clear, 'Clear formatting (Ctrl/Cmd+D)', onClearFormatting),
                _tool(Icons.looks, 'Toggle slur (Ctrl/Cmd+A)', onToggleSlur),
                const VerticalDivider(width: 16, indent: 12, endIndent: 12),
                for (final symbol in const [
                  '𝄆', '𝄋', '𝄌', '𝄍', '𝄎', '𝄏', '𝄇', '𝄁', '𝄂',
                ])
                  IconButton(
                    tooltip: 'Insert $symbol',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onInsertSymbol(symbol),
                    icon: Text(
                      symbol,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
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
