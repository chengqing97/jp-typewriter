import 'package:flutter/material.dart';

import 'editor/super_editor_spacing_prototype.dart';

void main() {
  runApp(const SuperEditorPrototypeApp());
}

class SuperEditorPrototypeApp extends StatelessWidget {
  const SuperEditorPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jianpu SuperEditor Prototype',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SuperEditorSpacingPrototype(),
    );
  }
}
