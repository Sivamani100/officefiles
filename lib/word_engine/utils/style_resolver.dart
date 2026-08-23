import 'package:flutter/material.dart';

import '../model/paragraph_model.dart';
import '../model/run_model.dart';
import '../model/style_model.dart';
import '../model/numbering_model.dart';

/// Resolved style properties for a run within a paragraph.
/// Each field is resolved independently through the 6-level inheritance chain.
class EffectiveStyle {
  String? fontAscii;
  String? fontCS;
  int? fontSizeHalfPt;
  bool? bold;
  bool? italic;
  bool? boldCs;
  bool? italicCs;
  bool? rtl;
  UnderlineType? underline;
  Color? underlineColor;
  Color? color;
  Color? highlight;
  Color? background;
  bool? strikethrough;
  bool? doubleStrikethrough;
  VerticalAlignment? vertAlign;
  bool? allCaps;
  bool? smallCaps;
  bool? shadow;
  bool? outline;
  bool? vanish;
  int? characterSpacingTwentieths;

  EffectiveStyle({
    this.fontAscii,
    this.fontCS,
    this.fontSizeHalfPt,
    this.bold,
    this.italic,
    this.boldCs,
    this.italicCs,
    this.rtl,
    this.underline,
    this.underlineColor,
    this.color,
    this.highlight,
    this.background,
    this.strikethrough,
    this.doubleStrikethrough,
    this.vertAlign,
    this.allCaps,
    this.smallCaps,
    this.shadow,
    this.outline,
    this.vanish,
    this.characterSpacingTwentieths,
  });
}

/// Resolved style properties for a paragraph.
class EffectiveParagraphStyle {
  ParagraphAlignment alignment;
  int spacingBeforeDxa;
  int spacingAfterDxa;
  int lineSpacingValue;
  LineSpacingRule lineSpacingRule;
  int indentLeftDxa;
  int indentRightDxa;
  int indentFirstLineDxa;
  int indentHangingDxa;
  bool keepWithNext;
  bool keepLines;
  bool pageBreakBefore;
  bool contextualSpacing;
  Color? shading;
  Map<String, dynamic>? borders;
  bool bidi;

  EffectiveParagraphStyle({
    required this.alignment,
    required this.spacingBeforeDxa,
    required this.spacingAfterDxa,
    required this.lineSpacingValue,
    required this.lineSpacingRule,
    required this.indentLeftDxa,
    required this.indentRightDxa,
    required this.indentFirstLineDxa,
    required this.indentHangingDxa,
    required this.keepWithNext,
    required this.keepLines,
    required this.pageBreakBefore,
    required this.contextualSpacing,
    this.shading,
    this.borders,
    required this.bidi,
  });
}

/// Resolves effective run styling through a 6-level inheritance chain:
///
/// 1. Direct run properties (highest priority)
/// 2. Character style (rStyle on run)
/// 3. Paragraph default rPr
/// 4. Paragraph style rPr (pStyle → style lookup)
/// 5. basedOn chain (walk basedOn links)
/// 6. Document defaults (Normal style)
class StyleResolver {
  static EffectiveStyle resolve(
    ParagraphModel paragraph,
    RunModel run,
    Map<String, StyleModel> styles,
  ) {
    final effective = EffectiveStyle();

    // Level 1: Direct run properties (highest priority)
    _applyRunProperties(effective, run);

    // Level 2: Character style (if run had an rStyle — lookup in styles map)
    if (run.rStyle != null) {
      final charStyle = styles[run.rStyle!.toLowerCase()];
      if (charStyle != null) {
        _mergeStyle(effective, charStyle.runProperties);
        _applyBasedOnChain(effective, charStyle, styles);
      }
    }

    // Level 3: Paragraph default run properties (rPr on the paragraph itself)
    if (paragraph.defaultRunProperties != null) {
      _mergeStyle(effective, paragraph.defaultRunProperties!);
    }

    // Level 4: Paragraph style's run properties
    if (paragraph.styleId != null) {
      final paragraphStyle = styles[paragraph.styleId!.toLowerCase()];
      if (paragraphStyle != null) {
        _mergeStyle(effective, paragraphStyle.runProperties);

        // Level 5: Walk the basedOn chain
        _applyBasedOnChain(effective, paragraphStyle, styles);
      }
    }

    // Level 6: Document defaults — try 'normal' style first, then fallback to 'docdefaults'
    final normalStyle = styles['normal'];
    if (normalStyle != null) {
      _mergeStyle(effective, normalStyle.runProperties);
    }
    final docDefaults = styles['docdefaults'];
    if (docDefaults != null) {
      _mergeStyle(effective, docDefaults.runProperties);
    }

    return effective;
  }

  static void _applyRunProperties(EffectiveStyle effective, RunModel run) {
    effective.fontAscii ??= run.fontAscii;
    effective.fontCS ??= run.fontCS;
    effective.fontSizeHalfPt ??= run.fontSizeHalfPt;
    effective.bold ??= run.bold;
    effective.italic ??= run.italic;
    effective.boldCs ??= run.boldCs;
    effective.italicCs ??= run.italicCs;
    effective.rtl ??= run.rtl;
    effective.underline ??= run.underline;
    effective.underlineColor ??= run.underlineColor;
    effective.color ??= run.color;
    effective.highlight ??= run.highlight;
    effective.background ??= run.background;
    effective.strikethrough ??= run.strikethrough;
    effective.doubleStrikethrough ??= run.doubleStrikethrough;
    effective.vertAlign ??= run.vertAlign;
    effective.allCaps ??= run.allCaps;
    effective.smallCaps ??= run.smallCaps;
    effective.shadow ??= run.shadow;
    effective.outline ??= run.outline;
    effective.vanish ??= run.vanish;
    effective.characterSpacingTwentieths ??= run.characterSpacingTwentieths;
  }

  static void _applyBasedOnChain(
    EffectiveStyle effective,
    StyleModel style,
    Map<String, StyleModel> styles,
  ) {
    var current = style;
    final visited = <String>{style.styleId};
    while (current.basedOn != null && styles.containsKey(current.basedOn!.toLowerCase())) {
      if (visited.contains(current.basedOn)) break; // prevent infinite loops
      current = styles[current.basedOn!.toLowerCase()]!;
      visited.add(current.styleId);
      _mergeStyle(effective, current.runProperties);
    }
  }

  static void _mergeStyle(EffectiveStyle effective, Map<String, dynamic> properties) {
    effective.fontAscii ??= properties['fontAscii'] as String?;
    effective.fontCS ??= properties['fontCS'] as String?;
    effective.fontSizeHalfPt ??= properties['fontSize'] as int?;
    effective.bold ??= properties['bold'] as bool?;
    effective.italic ??= properties['italic'] as bool?;
    effective.boldCs ??= properties['boldCs'] as bool?;
    effective.italicCs ??= properties['italicCs'] as bool?;
    effective.rtl ??= properties['rtl'] as bool?;
    effective.underline ??= properties['underline'] as UnderlineType?;
    effective.underlineColor ??= properties['underlineColor'] as Color?;
    effective.color ??= properties['color'] as Color?;
    effective.highlight ??= properties['highlight'] as Color?;
    effective.background ??= properties['background'] as Color?;
    effective.strikethrough ??= properties['strikethrough'] as bool?;
    effective.doubleStrikethrough ??= properties['doubleStrikethrough'] as bool?;
    effective.vertAlign ??= properties['vertAlign'] as VerticalAlignment?;
    effective.allCaps ??= properties['allCaps'] as bool?;
    effective.smallCaps ??= properties['smallCaps'] as bool?;
    effective.shadow ??= properties['shadow'] as bool?;
    effective.outline ??= properties['outline'] as bool?;
    effective.vanish ??= properties['vanish'] as bool?;
    effective.characterSpacingTwentieths ??= properties['characterSpacingTwentieths'] as int?;
  }

  static EffectiveParagraphStyle resolveParagraph(
    ParagraphModel paragraph,
    Map<String, StyleModel> styles,
  ) {
    ParagraphAlignment? alignment = paragraph.alignment;
    int? spacingBeforeDxa = paragraph.spacingBeforeDxa;
    int? spacingAfterDxa = paragraph.spacingAfterDxa;
    int? lineSpacingValue = paragraph.lineSpacingValue;
    LineSpacingRule? lineSpacingRule = paragraph.lineSpacingRule;
    int? indentLeftDxa = paragraph.indentLeftDxa;
    int? indentRightDxa = paragraph.indentRightDxa;
    int? indentFirstLineDxa = paragraph.indentFirstLineDxa;
    int? indentHangingDxa = paragraph.indentHangingDxa;
    bool? keepWithNext = paragraph.keepWithNext;
    bool? keepLines = paragraph.keepLines;
    bool? pageBreakBefore = paragraph.pageBreakBefore;
    bool? contextualSpacing = paragraph.contextualSpacing;
    Color? shading = paragraph.shading;
    Map<String, dynamic>? borders = paragraph.borders;
    bool? bidi = paragraph.bidi;

    void mergeFromMap(Map<String, dynamic> props) {
      alignment ??= _parseAlignment(props['alignment']);
      spacingBeforeDxa ??= props['spacingBefore'] as int?;
      spacingAfterDxa ??= props['spacingAfter'] as int?;
      lineSpacingValue ??= props['line'] as int?;
      lineSpacingRule ??= _parseLineSpacingRule(props['lineRule']);
      indentLeftDxa ??= props['indentLeft'] as int?;
      indentRightDxa ??= props['indentRight'] as int?;
      indentFirstLineDxa ??= props['indentFirstLine'] as int?;
      indentHangingDxa ??= props['indentHanging'] as int?;
      keepWithNext ??= props['keepNext'] as bool?;
      keepLines ??= props['keepLines'] as bool?;
      pageBreakBefore ??= props['pageBreakBefore'] as bool?;
      contextualSpacing ??= props['contextualSpacing'] as bool?;
      shading ??= props['shading'] as Color?;
      borders ??= props['borders'] as Map<String, dynamic>?;
      bidi ??= props['bidi'] as bool?;
    }

    if (paragraph.styleId != null) {
      final style = styles[paragraph.styleId!.toLowerCase()];
      if (style != null) {
        mergeFromMap(style.paragraphProperties);
        var current = style;
        final visited = <String>{style.styleId};
        while (current.basedOn != null && styles.containsKey(current.basedOn!.toLowerCase())) {
          if (visited.contains(current.basedOn)) break;
          current = styles[current.basedOn!.toLowerCase()]!;
          visited.add(current.styleId);
          mergeFromMap(current.paragraphProperties);
        }
      }
    }

    final normalStyle = styles['normal'];
    if (normalStyle != null) {
      mergeFromMap(normalStyle.paragraphProperties);
    }
    final docDefaults = styles['docdefaults'];
    if (docDefaults != null) {
      mergeFromMap(docDefaults.paragraphProperties);
    }

    return EffectiveParagraphStyle(
      alignment: alignment ?? ParagraphAlignment.left,
      spacingBeforeDxa: spacingBeforeDxa ?? 0,
      spacingAfterDxa: spacingAfterDxa ?? 0,
      lineSpacingValue: lineSpacingValue ?? 240,
      lineSpacingRule: lineSpacingRule ?? LineSpacingRule.auto,
      indentLeftDxa: indentLeftDxa ?? 0,
      indentRightDxa: indentRightDxa ?? 0,
      indentFirstLineDxa: indentFirstLineDxa ?? 0,
      indentHangingDxa: indentHangingDxa ?? 0,
      keepWithNext: keepWithNext ?? false,
      keepLines: keepLines ?? false,
      pageBreakBefore: pageBreakBefore ?? false,
      contextualSpacing: contextualSpacing ?? false,
      shading: shading,
      borders: borders,
      bidi: bidi ?? false,
    );
  }

  static ParagraphAlignment? _parseAlignment(dynamic value) {
    if (value is ParagraphAlignment) return value;
    if (value is String) {
      switch (value) {
        case 'center': return ParagraphAlignment.center;
        case 'right': return ParagraphAlignment.right;
        case 'both': return ParagraphAlignment.both;
        case 'distribute': return ParagraphAlignment.distribute;
        default: return ParagraphAlignment.left;
      }
    }
    return null;
  }

  static LineSpacingRule? _parseLineSpacingRule(dynamic value) {
    if (value is LineSpacingRule) return value;
    if (value is String) {
      switch (value) {
        case 'exact': return LineSpacingRule.exact;
        case 'atLeast': return LineSpacingRule.atLeast;
        default: return LineSpacingRule.auto;
      }
    }
    return null;
  }

  /// Resolves the numbering reference of a paragraph, checking direct numbering
  /// first, then walking the stylesheet's inheritance chain (basedOn).
  static NumberingReference? resolveNumbering(
    ParagraphModel paragraph,
    Map<String, StyleModel> styles,
  ) {
    if (paragraph.numbering != null) {
      return paragraph.numbering;
    }
    if (paragraph.styleId != null) {
      var currentId = paragraph.styleId!;
      final visited = <String>{currentId.toLowerCase()};
      while (styles.containsKey(currentId.toLowerCase())) {
        final style = styles[currentId.toLowerCase()]!;
        final styleNum = style.paragraphProperties['numbering'];
        if (styleNum is Map) {
          final numId = styleNum['numId'] as String?;
          final ilvl = styleNum['ilvl'] as int?;
          if (numId != null && ilvl != null) {
            return NumberingReference(numId: numId, ilvl: ilvl);
          }
        }
        if (style.basedOn != null && !visited.contains(style.basedOn!.toLowerCase())) {
          currentId = style.basedOn!;
          visited.add(currentId.toLowerCase());
        } else {
          break;
        }
      }
    }
    return null;
  }
}
