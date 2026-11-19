import 'dart:convert';

import 'package:super_clipboard/super_clipboard.dart';

import '../models/jianpu_document.dart';

class JianpuClipboardCodec {
  static const format = CustomValueFormat<String>(
    applicationId: 'com.chengqing97.jptypewriter.jianpu-runs',
  );

  static String encodeRuns(List<JianpuRun> runs) => jsonEncode({
        'version': 1,
        'runs': runs
            .map((run) => {
                  'text': run.text,
                  'octave': run.octave,
                  'beam': run.beam,
                  'superscript': run.superscript,
                  'italic': run.italic,
                  'slurId': run.slurId,
                  'lineSpacingBefore': run.lineSpacingBefore
                })
            .toList(),
      });

  static String encodeHtmlClipboard(List<JianpuRun> runs, String plain) {
    final payload = base64Url.encode(utf8.encode(encodeRuns(runs)));
    final escaped = plain
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '<!--jianpu-runs:$payload--><pre>$escaped</pre>';
  }

  static List<JianpuRun>? decodeRuns(String payload) {
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
                item['slurId'] is String ? item['slurId'] as String : null,
            lineSpacingBefore: item['lineSpacingBefore'] is int
                ? (item['lineSpacingBefore'] as int).clamp(0, 40)
                : 0));
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
