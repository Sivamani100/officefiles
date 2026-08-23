import '../model/numbering_model.dart';
import '../model/paragraph_model.dart';
import '../model/section_model.dart';
import '../model/style_model.dart';
import 'style_resolver.dart';

/// Pre-computed numbering info for a single block.
class NumberingInfo {
  final String label;
  final NumberingLevel level;

  NumberingInfo({required this.label, required this.level});
}

/// Centralized utility that computes numbering labels for an entire document
/// in a single pass, so counters flow correctly across page boundaries.
class NumberingFormatter {
  /// Computes labels for every numbered paragraph across all sections.
  /// Returns a map keyed by global block index.
  static Map<int, NumberingInfo> computeAllLabels(
    List<SectionModel> sections,
    Map<String, NumberingDefinition> numbering,
    Map<String, AbstractNumDefinition> abstractNumbering,
    Map<String, StyleModel> styles,
  ) {
    final result = <int, NumberingInfo>{};
    // Counters keyed by numId → (ilvl → currentCount)
    final counters = <String, Map<int, int>>{};

    int globalIndex = 0;
    for (final section in sections) {
      for (final block in section.blocks) {
        if (block is ParagraphModel) {
          final numRef = StyleResolver.resolveNumbering(block, styles);
          if (numRef != null) {
            final definition = numbering[numRef.numId];
            if (definition != null) {
              final abstractNum = abstractNumbering[definition.abstractNumId];
              if (abstractNum != null) {
                final level = abstractNum.levels[numRef.ilvl];
                if (level != null) {
                  final label = _computeLabel(
                    numRef.numId,
                    numRef.ilvl,
                    level,
                    abstractNum,
                    numbering,
                    counters,
                  );
                  result[globalIndex] = NumberingInfo(label: label, level: level);
                }
              }
            }
          }
        }
        globalIndex++;
      }
    }

    return result;
  }

  static String _computeLabel(
    String numId,
    int ilvl,
    NumberingLevel level,
    AbstractNumDefinition abstractNum,
    Map<String, NumberingDefinition> numbering,
    Map<String, Map<int, int>> counters,
  ) {
    final levelCounters = counters.putIfAbsent(numId, () => {});

    // Reset deeper levels when a higher level appears
    for (final levelIndex in levelCounters.keys.toList()) {
      if (levelIndex > ilvl) {
        levelCounters.remove(levelIndex);
      }
    }

    // Increment counter for this level, using start value (or override) on first use
    var startValue = level.start ?? 1;
    final definition = numbering[numId];
    if (definition != null && definition.startOverrides.containsKey(ilvl)) {
      startValue = definition.startOverrides[ilvl]!;
    }

    if (!levelCounters.containsKey(ilvl)) {
      levelCounters[ilvl] = startValue;
    } else {
      levelCounters[ilvl] = levelCounters[ilvl]! + 1;
    }
    final currentCount = levelCounters[ilvl]!;

    // Format the label
    if (level.format == NumberFormat.bullet) {
      return '•';
    }

    final textPattern = level.text;
    if (textPattern != null && textPattern.isNotEmpty) {
      var result = textPattern;
      // Replace %1, %2, etc. with formatted counter values
      for (int index = 0; index <= ilvl; index++) {
        var count = levelCounters[index];
        if (count == null) {
          count = abstractNum.levels[index]?.start ?? 1;
          if (definition != null && definition.startOverrides.containsKey(index)) {
            count = definition.startOverrides[index]!;
          }
        }
        final lvl = abstractNum.levels[index];
        final fmt = lvl?.format ?? level.format;
        result = result.replaceAll('%${index + 1}', formatNumber(count, fmt));
      }
      return result;
    }

    // Fallback: just format the number
    return '${formatNumber(currentCount, level.format)}.';
  }

  /// Converts a counter value to the appropriate string for the given format.
  static String formatNumber(int value, NumberFormat format) {
    switch (format) {
      case NumberFormat.decimal:
        return '$value';
      case NumberFormat.decimalZero:
        return value < 10 ? '0$value' : '$value';
      case NumberFormat.lowerLetter:
        return _toLowerLetter(value);
      case NumberFormat.upperLetter:
        return _toUpperLetter(value);
      case NumberFormat.lowerRoman:
        return _toRoman(value).toLowerCase();
      case NumberFormat.upperRoman:
        return _toRoman(value);
      case NumberFormat.bullet:
        return '•';
      case NumberFormat.none:
        return '';
    }
  }

  static String _toLowerLetter(int value) {
    if (value <= 0) return '';
    final buffer = StringBuffer();
    var n = value;
    while (n > 0) {
      n--;
      buffer.write(String.fromCharCode(97 + (n % 26))); // 'a' = 97
      n ~/= 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _toUpperLetter(int value) {
    return _toLowerLetter(value).toUpperCase();
  }

  static String _toRoman(int value) {
    if (value <= 0) return '';
    const romanNumerals = [
      [1000, 'M'],
      [900, 'CM'],
      [500, 'D'],
      [400, 'CD'],
      [100, 'C'],
      [90, 'XC'],
      [50, 'L'],
      [40, 'XL'],
      [10, 'X'],
      [9, 'IX'],
      [5, 'V'],
      [4, 'IV'],
      [1, 'I'],
    ];
    final buffer = StringBuffer();
    var remaining = value;
    for (final pair in romanNumerals) {
      final threshold = pair[0] as int;
      final numeral = pair[1] as String;
      while (remaining >= threshold) {
        buffer.write(numeral);
        remaining -= threshold;
      }
    }
    return buffer.toString();
  }
}
