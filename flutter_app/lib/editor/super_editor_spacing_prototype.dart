import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Isolated spike for testing paragraph-level spacing before migrating the
/// production Jianpu editor. Run with:
/// flutter run -t lib/main_super_editor_prototype.dart
class SuperEditorSpacingPrototype extends StatefulWidget {
  const SuperEditorSpacingPrototype({super.key});

  @override
  State<SuperEditorSpacingPrototype> createState() =>
      _SuperEditorSpacingPrototypeState();
}

class _SuperEditorSpacingPrototypeState
    extends State<SuperEditorSpacingPrototype> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final DocumentEditor _editor;

  static const _spacingKey = 'lineSpacingBefore';

  @override
  void initState() {
    super.initState();
    _document = MutableDocument(
      nodes: [
        _paragraph('4 4 5 5 | 6 6 5 -'),
        _paragraph('4 4 3 3 | 2 2 1 -'),
        _paragraph('1 1 2 3 | 3 2 2 -'),
        _paragraph('1 1 2 3 | 3 2 2 -'),
      ],
    );
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );
  }

  ParagraphNode _paragraph(String text) => ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text),
        metadata: const {_spacingKey: 0},
      );

  int _spacingFor(DocumentNode node) =>
      (node.metadata[_spacingKey] as int?) ?? 0;

  void _changeSpacing(int index, int delta) {
    final node = _document.getNodeAt(index);
    if (node is! ParagraphNode) return;
    final next = (_spacingFor(node) + delta).clamp(0, 80);
    node.putMetadataValue(_spacingKey, next);
    setState(() {});
  }

  Stylesheet get _stylesheet => defaultStylesheet.copyWith(
        addRulesAfter: [
          StyleRule(
            const BlockSelector('paragraph'),
            (document, node) {
              if (node is! ParagraphNode) return const {};
              final spacing = _spacingFor(node).toDouble();
              return {
                Styles.padding: CascadingPadding.only(top: spacing),
                Styles.textStyle: const TextStyle(
                  fontSize: 28,
                  height: 1.35,
                  color: Colors.black,
                ),
              };
            },
          ),
        ],
      );

  @override
  void dispose() {
    _editor.dispose();
    _composer.dispose();
    _document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SuperEditor spacing prototype'),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Adjust spacing before each line, then try selecting '
                      'across lines and typing between them.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 600,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.fromLTRB(48, 48, 48, 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: SuperEditor(
                  editor: _editor,
                  composer: _composer,
                  stylesheet: _stylesheet,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(4, (index) {
                  final node = _document.getNodeAt(index);
                  final spacing = node == null ? 0 : _spacingFor(node);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Line ${index + 1}: ${spacing}px'),
                      IconButton(
                        tooltip: 'Decrease line ${index + 1} spacing',
                        onPressed: spacing == 0
                            ? null
                            : () => _changeSpacing(index, -8),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip: 'Increase line ${index + 1} spacing',
                        onPressed: () => _changeSpacing(index, 8),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
