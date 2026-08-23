import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../model/run_model.dart';
import '../model/style_model.dart';
import '../utils/font_mapper.dart';
import '../utils/style_resolver.dart';
import '../utils/unit_converter.dart';
import 'image_renderer.dart';

class RunRenderer {
  /// Builds an [InlineSpan] for a single [RunModel] within a paragraph.
  static InlineSpan buildRunSpan(
    RunModel run,
    EffectiveStyle effective,
    EffectiveParagraphStyle effectiveParagraph,
    List<RunModel> allRuns,
    int runIndex,
    int pageIndex,
    int totalPages,
    List<dynamic> customTabStops,
    void Function(String? url, String? anchor)? onHyperlinkTap,
  ) {
    if (run.vanish ?? effective.vanish ?? false) {
      return const TextSpan(text: '');
    }

    switch (run.type) {
      case RunType.tab:
        // Calculate tab stop width dynamically
        double precedingWidth = 0.0;
        for (int j = runIndex - 1; j >= 0; j--) {
          final prevRun = allRuns[j];
          if (prevRun.type == RunType.lineBreak || prevRun.type == RunType.pageBreak) {
            break;
          }
          if (prevRun.type == RunType.text) {
            final fs = UnitConverter.halfPointToPx(prevRun.fontSizeHalfPt ?? effective.fontSizeHalfPt ?? 22);
            precedingWidth += prevRun.text.length * fs * 0.55;
          } else if (prevRun.type == RunType.tab) {
            precedingWidth += 48.0;
          } else if (prevRun.type == RunType.image && prevRun.image != null) {
            precedingWidth += UnitConverter.emuToPx(prevRun.image!.widthEmu);
          }
        }

        final tabStopsPx = <double>[];
        for (final tab in customTabStops) {
          final posDxa = tab['pos'] as int? ?? 0;
          tabStopsPx.add(UnitConverter.dxaToPx(posDxa));
        }
        tabStopsPx.sort();

        double targetTabPx = 0.0;
        for (final stopPx in tabStopsPx) {
          if (stopPx > precedingWidth + 4.0) {
            targetTabPx = stopPx;
            break;
          }
        }

        if (targetTabPx == 0.0) {
          const defaultTabWidthPx = 48.0; // 720 DXA
          final currentTabMultiplier = (precedingWidth / defaultTabWidthPx).floor() + 1;
          targetTabPx = currentTabMultiplier * defaultTabWidthPx;
        }

        final tabWidth = (targetTabPx - precedingWidth).clamp(8.0, double.infinity);
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(width: tabWidth),
        );

      case RunType.lineBreak:
        return const TextSpan(text: '\n');

      case RunType.pageBreak:
        return const TextSpan(text: '');

      case RunType.image:
        if (run.image != null) {
          if (run.image!.wrapType != 'inline') {
            return const TextSpan(text: '');
          }
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ImageRenderer.buildInlineImage(run.image!),
          );
        }
        return const TextSpan(text: ' ');

      case RunType.symbol:
        return _buildSymbolSpan(run, effective, effectiveParagraph);

      case RunType.text:
        return _buildTextSpan(run, effective, effectiveParagraph, pageIndex, totalPages, onHyperlinkTap);
    }
  }

  // ---------------------------------------------------------------------------
  // Text runs
  // ---------------------------------------------------------------------------

  static InlineSpan _buildTextSpan(
    RunModel run,
    EffectiveStyle effective,
    EffectiveParagraphStyle effectiveParagraph,
    int pageIndex,
    int totalPages,
    void Function(String? url, String? anchor)? onHyperlinkTap,
  ) {
    final style = buildTextStyle(run, effective, effectiveParagraph);
    String text = run.text;

    // Evaluate dynamic fields
    if (run.fieldCode == 'PAGE') {
      text = '${pageIndex + 1}';
    } else if (run.fieldCode == 'NUMPAGES') {
      text = '$totalPages';
    }

    final isAllCaps = run.allCaps ?? effective.allCaps ?? false;
    final isSmallCaps = run.smallCaps ?? effective.smallCaps ?? false;

    if (isAllCaps || isSmallCaps) {
      text = text.toUpperCase();
    }

    final hasLink = run.hyperlinkId != null || run.hyperlinkAnchor != null;
    TapGestureRecognizer? recognizer;
    if (hasLink && onHyperlinkTap != null) {
      recognizer = TapGestureRecognizer()
        ..onTap = () {
          onHyperlinkTap(run.hyperlinkId, run.hyperlinkAnchor);
        };
    }

    final vertAlign = run.vertAlign ?? effective.vertAlign;
    if (vertAlign == VerticalAlignment.superscript ||
        vertAlign == VerticalAlignment.subscript) {
      final baseFontSize = UnitConverter.halfPointToPx(run.fontSizeHalfPt ?? effective.fontSizeHalfPt ?? 22);
      final offset = vertAlign == VerticalAlignment.superscript
          ? -baseFontSize * 0.3
          : baseFontSize * 0.15;

      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: hasLink && onHyperlinkTap != null
              ? () => onHyperlinkTap(run.hyperlinkId, run.hyperlinkAnchor)
              : null,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Text(
              text,
              style: style,
            ),
          ),
        ),
      );
    }

    return TextSpan(text: text, style: style, recognizer: recognizer);
  }

  // ---------------------------------------------------------------------------
  // Symbol runs
  // ---------------------------------------------------------------------------

  static InlineSpan _buildSymbolSpan(
    RunModel run,
    EffectiveStyle effective,
    EffectiveParagraphStyle effectiveParagraph,
  ) {
    if (run.symbolCharCode != null) {
      try {
        final char = String.fromCharCode(run.symbolCharCode!);
        final fontFamily = FontMapper.resolveSymbolFont(run.symbolFont);
        final fontSize = UnitConverter.halfPointToPx(run.fontSizeHalfPt ?? effective.fontSizeHalfPt ?? 22);
        final color = run.color ?? effective.color ?? Colors.black;
        return TextSpan(
          text: char,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            color: color,
          ),
        );
      } catch (_) {
        // Fall through to placeholder
      }
    }
    return const TextSpan(text: '\u25A1'); // □
  }

  // ---------------------------------------------------------------------------
  // TextStyle construction
  // ---------------------------------------------------------------------------

  static TextStyle buildTextStyle(
    RunModel run,
    EffectiveStyle effective,
    EffectiveParagraphStyle effectiveParagraph,
  ) {
    final isRtl = run.rtl ?? effective.rtl ?? false;
    final fontFamilyName = isRtl
        ? (run.fontCS ?? effective.fontCS ?? run.fontAscii ?? effective.fontAscii)
        : (run.fontAscii ?? effective.fontAscii);

    final fontFamily = FontMapper.resolve(fontFamilyName);
    double fontSize = UnitConverter.halfPointToPx(run.fontSizeHalfPt ?? effective.fontSizeHalfPt ?? 22);
    
    // Fallback bold/italic for complex scripts
    final bold = run.bold ?? run.boldCs ?? effective.bold ?? effective.boldCs ?? false;
    final italic = run.italic ?? run.italicCs ?? effective.italic ?? effective.italicCs ?? false;

    // Hyperlink default styling (blue + single underline) if no overrides are present
    final isHyperlink = run.hyperlinkId != null || run.hyperlinkAnchor != null;
    final color = run.color ?? effective.color ?? (isHyperlink ? Colors.blue : Colors.black);
    final underlineVal = run.underline ?? effective.underline ?? (isHyperlink ? UnderlineType.single : null);

    final decoration = _buildDecoration(run, effective, underlineVal);

    // Underline style and color
    TextDecorationStyle? decorationStyle;
    if (underlineVal != null) {
      switch (underlineVal) {
        case UnderlineType.double:
          decorationStyle = TextDecorationStyle.double;
          break;
        case UnderlineType.dotted:
          decorationStyle = TextDecorationStyle.dotted;
          break;
        case UnderlineType.dashed:
          decorationStyle = TextDecorationStyle.dashed;
          break;
        case UnderlineType.wave:
          decorationStyle = TextDecorationStyle.wavy;
          break;
        default:
          decorationStyle = TextDecorationStyle.solid;
      }
    }
    final underlineColor = run.underlineColor ?? effective.underlineColor ?? color;

    // Shadow
    final hasShadow = run.shadow ?? effective.shadow ?? false;
    List<Shadow>? shadows;
    if (hasShadow) {
      shadows = [
        Shadow(
          color: color.withOpacity(0.5),
          offset: const Offset(1.5, 1.5),
          blurRadius: 1.0,
        ),
      ];
    }

    // Outline
    final isOutline = run.outline ?? effective.outline ?? false;
    Paint? foregroundPaint;
    if (isOutline) {
      foregroundPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = color;
    }

    // Vertical alignment — superscript / subscript
    final vertAlign = run.vertAlign ?? effective.vertAlign;
    if (vertAlign == VerticalAlignment.superscript ||
        vertAlign == VerticalAlignment.subscript) {
      fontSize = fontSize * 0.65;
    }

    // Small caps — visually rendered at 80 % size
    final isSmallCaps = run.smallCaps ?? effective.smallCaps ?? false;
    if (isSmallCaps) {
      fontSize = fontSize * 0.8;
    }

    // Letter spacing
    final int? spacingTw = run.characterSpacingTwentieths ?? effective.characterSpacingTwentieths;
    double? letterSpacing;
    if (spacingTw != null) {
      letterSpacing = UnitConverter.twentiethsOfPointToPx(spacingTw);
    } else if (fontFamilyName == 'Calibri') {
      letterSpacing = -(fontSize * 0.02);
    }

    // Font features
    List<FontFeature>? fontFeatures;
    if (vertAlign == VerticalAlignment.superscript) {
      fontFeatures = [const FontFeature.superscripts()];
    } else if (vertAlign == VerticalAlignment.subscript) {
      fontFeatures = [const FontFeature.subscripts()];
    }

    try {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: decoration,
        decorationColor: underlineColor,
        decorationStyle: decorationStyle,
        shadows: shadows,
        foreground: foregroundPaint,
        color: isOutline ? null : color,
        backgroundColor: run.highlight ?? effective.highlight ?? run.background ?? effective.background,
        letterSpacing: letterSpacing,
        height: _computeLineHeight(effectiveParagraph, fontSize),
        fontFeatures: fontFeatures,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: decoration,
        decorationColor: underlineColor,
        decorationStyle: decorationStyle,
        shadows: shadows,
        foreground: foregroundPaint,
        color: isOutline ? null : color,
        backgroundColor: run.highlight ?? effective.highlight ?? run.background ?? effective.background,
        letterSpacing: letterSpacing,
        height: _computeLineHeight(effectiveParagraph, fontSize),
        fontFeatures: fontFeatures,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Text decoration (underline, strikethrough)
  // ---------------------------------------------------------------------------

  static TextDecoration? _buildDecoration(RunModel run, EffectiveStyle effective, UnderlineType? underlineVal) {
    final decorations = <TextDecoration>[];

    if (underlineVal != null && underlineVal != UnderlineType.none) {
      decorations.add(TextDecoration.underline);
    }

    if (run.strikethrough ?? effective.strikethrough ?? false) {
      decorations.add(TextDecoration.lineThrough);
    }

    if (run.doubleStrikethrough ?? effective.doubleStrikethrough ?? false) {
      if (!decorations.contains(TextDecoration.lineThrough)) {
        decorations.add(TextDecoration.lineThrough);
      }
    }

    if (decorations.isEmpty) return null;
    return TextDecoration.combine(decorations);
  }

  // ---------------------------------------------------------------------------
  // Line height
  // ---------------------------------------------------------------------------

  static double _computeLineHeight(EffectiveParagraphStyle effectiveParagraph, double fontSizePx) {
    final value = effectiveParagraph.lineSpacingValue;
    switch (effectiveParagraph.lineSpacingRule) {
      case LineSpacingRule.exact:
        final lineHeightPt = value / 20.0;
        final lineHeightPx = lineHeightPt * 96.0 / 72.0;
        return lineHeightPx / fontSizePx;
      case LineSpacingRule.atLeast:
        final minHeightPt = value / 20.0;
        final minHeightPx = minHeightPt * 96.0 / 72.0;
        final naturalHeight = fontSizePx * 1.2;
        return (minHeightPx > naturalHeight ? minHeightPx : naturalHeight) / fontSizePx;
      case LineSpacingRule.auto:
        return (value / 240.0) * 1.2;
    }
  }
}
