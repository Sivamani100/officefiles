enum NumberFormat { bullet, decimal, decimalZero, lowerLetter, upperLetter, lowerRoman, upperRoman, none }

class NumberingLevel {
  final NumberFormat format;
  final String? text;
  final int? start;
  final int? indent;
  final int? hanging;
  final Map<String, dynamic> rPr;

  NumberingLevel({
    required this.format,
    this.text,
    this.start,
    this.indent,
    this.hanging,
    Map<String, dynamic>? rPr,
  }) : rPr = rPr ?? {};
}

class AbstractNumDefinition {
  final String id;
  final Map<int, NumberingLevel> levels;

  AbstractNumDefinition({required this.id, required this.levels});
}

class NumberingDefinition {
  final String numId;
  final String abstractNumId;
  final Map<int, int> startOverrides;

  NumberingDefinition({
    required this.numId,
    required this.abstractNumId,
    Map<int, int>? startOverrides,
  }) : startOverrides = startOverrides ?? {};
}

class NumberingReference {
  final String numId;
  final int ilvl;

  NumberingReference({required this.numId, required this.ilvl});
}

class NumberingParseResult {
  final Map<String, NumberingDefinition> numbering;
  final Map<String, AbstractNumDefinition> abstractNumbering;

  NumberingParseResult({
    required this.numbering,
    required this.abstractNumbering,
  });
}
