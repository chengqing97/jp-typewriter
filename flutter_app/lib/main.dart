import 'package:flutter/material.dart';

import 'editor/jianpu_editor_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JianpuApp());
}

class JianpuApp extends StatelessWidget {
  const JianpuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jianpu Typewriter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF526B8C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F3F6),
        useMaterial3: true,
      ),
      home: const JianpuEditorPage(),
    );
  }
}
