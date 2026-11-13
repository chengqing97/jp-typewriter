/// A formatting run in a Jianpu document.
///
/// Text offsets are kept in Dart's UTF-16 coordinate system so they can be
/// aligned with Flutter's TextSelection offsets.
class JianpuRun {
  const JianpuRun({
    required this.text,
    this.octave = 0,
    this.beam = 0,
    this.superscript = false,
    this.italic = false,
    this.slurId,
  });

  final String text;
  final int octave;
  final int beam;
  final bool superscript;
  final bool italic;
  final String? slurId;

  JianpuRun copyWith({
    String? text,
    int? octave,
    int? beam,
    bool? superscript,
    bool? italic,
    String? slurId,
  }) {
    return JianpuRun(
      text: text ?? this.text,
      octave: octave ?? this.octave,
      beam: beam ?? this.beam,
      superscript: superscript ?? this.superscript,
      italic: italic ?? this.italic,
      slurId: slurId ?? this.slurId,
    );
  }
}

/// The document model is deliberately independent of Flutter widgets.
class JianpuDocument {
  const JianpuDocument({this.runs = const []});

  final List<JianpuRun> runs;

  String get plainText => runs.map((run) => run.text).join();

  factory JianpuDocument.fromPlainText(String text) {
    return JianpuDocument(
      runs: text.isEmpty ? const [] : [JianpuRun(text: text)],
    );
  }
}
