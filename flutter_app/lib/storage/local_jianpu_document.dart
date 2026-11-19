import 'dart:convert';

import '../models/jianpu_document.dart';

class LocalJianpuDocument {
  const LocalJianpuDocument({
    required this.id,
    required this.title,
    required this.runs,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<JianpuRun> runs;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get plainText => runs.map((run) => run.text).join();

  String encodeContent() => jsonEncode({
        'version': 1,
        'runs': runs
            .map((run) => {
                  'text': run.text,
                  'octave': run.octave,
                  'beam': run.beam,
                  'superscript': run.superscript,
                  'italic': run.italic,
                  'slurId': run.slurId,
                  'lineSpacingBefore': run.lineSpacingBefore,
                })
            .toList(),
      });

  factory LocalJianpuDocument.fromRow(Map<String, Object?> row) {
    final decoded = jsonDecode(row['content_json'] as String) as Map;
    final runs = <JianpuRun>[];
    for (final item in decoded['runs'] as List) {
      if (item is! Map || item['text'] is! String) continue;
      runs.add(JianpuRun(
        text: item['text'] as String,
        octave: item['octave'] is int ? item['octave'] as int : 0,
        beam: item['beam'] is int ? item['beam'] as int : 0,
        superscript: item['superscript'] == true,
        italic: item['italic'] == true,
        slurId: item['slurId'] is String ? item['slurId'] as String : null,
        lineSpacingBefore: item['lineSpacingBefore'] is int
            ? (item['lineSpacingBefore'] as int).clamp(0, 40).toInt()
            : 0,
      ));
    }
    return LocalJianpuDocument(
      id: row['id'] as String,
      title: row['title'] as String,
      runs: runs,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
