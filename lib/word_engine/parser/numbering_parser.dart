import 'package:xml/xml.dart';
import '../utils/xml_extensions.dart';

import '../model/numbering_model.dart';
import '../model/theme_model.dart';
import '../utils/color_resolver.dart';

class NumberingParser {
  static NumberingParseResult parse(String xmlContent, {ThemeModel? theme}) {
    final document = XmlDocument.parse(xmlContent);
    final abstractNums = <String, AbstractNumDefinition>{};
    final numbering = <String, NumberingDefinition>{};

    for (final abstractNum in document.findAllElementsNS('abstractNum')) {
      final abstractNumId = abstractNum.getAttributeNS('abstractNumId');
      if (abstractNumId == null) continue;
      final levels = <int, NumberingLevel>{};
      for (final lvl in abstractNum.findElementsNS('lvl')) {
        final ilvl = int.tryParse(lvl.getAttributeNS('ilvl') ?? '0') ?? 0;
        final fmt = lvl.getElementNS('numFmt')?.getAttributeNS('val');
        final text = lvl.getElementNS('lvlText')?.getAttributeNS('val');
        final start = int.tryParse(lvl.getElementNS('start')?.getAttributeNS('val') ?? '1');

        // Parse indentation
        final pPr = lvl.getElementNS('pPr');
        final ind = pPr?.getElementNS('ind');
        final indent = int.tryParse(ind?.getAttributeNS('left') ?? '0');
        final hanging = int.tryParse(ind?.getAttributeNS('hanging') ?? '');

        // Parse run properties (font, size, color, bold, italic)
        final rPrElement = lvl.getElementNS('rPr');
        final rPrMap = <String, dynamic>{};
        if (rPrElement != null) {
          final rFonts = rPrElement.getElementNS('rFonts');
          if (rFonts != null) {
            final ascii = rFonts.getAttributeNS('ascii');
            final hAnsi = rFonts.getAttributeNS('hAnsi');
            final cs = rFonts.getAttributeNS('cs');
            if (ascii != null) rPrMap['fontAscii'] = ascii;
            if (hAnsi != null) rPrMap['fontHAnsi'] = hAnsi;
            if (cs != null) rPrMap['fontCS'] = cs;
          }
          final sz = rPrElement.getElementNS('sz')?.getAttributeNS('val');
          if (sz != null) rPrMap['fontSize'] = int.tryParse(sz);

          // Bold
          final bElem = rPrElement.getElementNS('b');
          if (bElem != null) {
            final bVal = bElem.getAttributeNS('val');
            rPrMap['bold'] = (bVal == null || (bVal != '0' && bVal != 'false'));
          }

          // Italic
          final iElem = rPrElement.getElementNS('i');
          if (iElem != null) {
            final iVal = iElem.getAttributeNS('val');
            rPrMap['italic'] = (iVal == null || (iVal != '0' && iVal != 'false'));
          }

          // Color (including theme, tint, shade)
          final colorElem = rPrElement.getElementNS('color');
          if (colorElem != null) {
            final colorVal = colorElem.getAttributeNS('val');
            final themeColor = colorElem.getAttributeNS('themeColor');
            final themeTint = colorElem.getAttributeNS('themeTint');
            final themeShade = colorElem.getAttributeNS('themeShade');
            if (colorVal != null || themeColor != null) {
              double? tint;
              if (themeTint != null) {
                final val = int.tryParse(themeTint, radix: 16);
                if (val != null) tint = val / 255.0;
              }
              double? shade;
              if (themeShade != null) {
                final val = int.tryParse(themeShade, radix: 16);
                if (val != null) shade = val / 255.0;
              }
              rPrMap['color'] = ColorResolver.resolve(
                hexValue: colorVal,
                themeColor: themeColor,
                tint: tint,
                shade: shade,
                theme: theme,
                isAutoText: true,
              );
            }
          }
        }

        levels[ilvl] = NumberingLevel(
          format: _parseNumberFormat(fmt),
          text: text,
          start: start,
          indent: indent,
          hanging: hanging,
          rPr: rPrMap,
        );
      }
      abstractNums[abstractNumId] = AbstractNumDefinition(id: abstractNumId, levels: levels);
    }

    for (final num in document.findAllElementsNS('num')) {
      final numId = num.getAttributeNS('numId');
      final abstractNumId = num.getElementNS('abstractNumId')?.getAttributeNS('val');
      if (numId == null || abstractNumId == null) continue;

      final startOverrides = <int, int>{};
      for (final lvlOverride in num.findElementsNS('lvlOverride')) {
        final ilvlVal = lvlOverride.getAttributeNS('ilvl');
        if (ilvlVal != null) {
          final ilvl = int.tryParse(ilvlVal);
          final startOverrideVal = lvlOverride.getElementNS('startOverride')?.getAttributeNS('val');
          if (ilvl != null && startOverrideVal != null) {
            final startVal = int.tryParse(startOverrideVal);
            if (startVal != null) {
              startOverrides[ilvl] = startVal;
            }
          }
        }
      }

      numbering[numId] = NumberingDefinition(
        numId: numId,
        abstractNumId: abstractNumId,
        startOverrides: startOverrides,
      );
    }

    return NumberingParseResult(
      numbering: numbering,
      abstractNumbering: abstractNums,
    );
  }

  static NumberFormat _parseNumberFormat(String? value) {
    switch (value) {
      case 'decimal':
      case 'ordinal':
      case 'cardinalText':
      case 'ordinalText':
      case 'chicago':
        return NumberFormat.decimal;
      case 'decimalZero':
        return NumberFormat.decimalZero;
      case 'lowerLetter':
        return NumberFormat.lowerLetter;
      case 'upperLetter':
        return NumberFormat.upperLetter;
      case 'lowerRoman':
        return NumberFormat.lowerRoman;
      case 'upperRoman':
        return NumberFormat.upperRoman;
      case 'bullet':
        return NumberFormat.bullet;
      default:
        return NumberFormat.none;
    }
  }
}
