import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import '../utils/xml_extensions.dart';

import '../model/document_model.dart';
import '../model/image_model.dart';
import '../model/numbering_model.dart';
import '../model/paragraph_model.dart';
import '../model/run_model.dart';
import '../model/section_model.dart';
import '../model/style_model.dart';
import '../model/theme_model.dart';
import '../model/table_model.dart';
import '../utils/color_resolver.dart';
import '../model/header_footer_model.dart';
import 'header_footer_parser.dart';

class DocumentParser {
  static const _highlightColorMap = <String, String>{
    'yellow': 'FFFF00',
    'green': '00FF00',
    'cyan': '00FFFF',
    'magenta': 'FF00FF',
    'blue': '0000FF',
    'red': 'FF0000',
    'darkBlue': '000080',
    'darkCyan': '008080',
    'darkGreen': '008000',
    'darkMagenta': '800080',
    'darkRed': '800000',
    'darkYellow': '808000',
    'darkGray': '808080',
    'lightGray': 'C0C0C0',
    'black': '000000',
  };

  static String _stripBom(String s) {
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) return s.substring(1);
    return s;
  }

  static DocumentModel parse(
    String xmlContent, {
    required Map<String, StyleModel> styles,
    required Map<String, NumberingDefinition> numbering,
    required Map<String, AbstractNumDefinition> abstractNumbering,
    required ThemeModel? theme,
    required Map<String, String> relationships,
    required Uint8List? Function(String path) readBinaryFile,
    bool differentOddEvenDefault = false,
    bool mirrorMarginsDefault = false,
  }) {
    final document = XmlDocument.parse(_stripBom(xmlContent));
    final body = document.findAllElementsNS('body').first;
    final sections = <SectionModel>[];
    var currentBlocks = <dynamic>[];

    // Helper to read text files from archive
    String? readFile(String path) {
      final bytes = readBinaryFile(path);
      if (bytes == null) return null;
      return String.fromCharCodes(bytes);
    }

    for (final element in body.children.whereType<XmlElement>()) {
      switch (element.name.local) {
        case 'p':
          final paragraph = parseParagraph(
            element,
            styles: styles,
            numbering: numbering,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
            theme: theme,
          );
          currentBlocks.add(paragraph);

          // Check if there is a sectPr inside pPr
          final pPr = element.getElementNS('pPr');
          final sectPr = pPr?.getElementNS('sectPr');
          if (sectPr != null) {
            final sec = _parseSection(
              sectPr,
              relationships: relationships,
              readBinaryFile: readBinaryFile,
              readFile: readFile,
              styles: styles,
              numbering: numbering,
              abstractNumbering: abstractNumbering,
              theme: theme,
              differentOddEvenDefault: differentOddEvenDefault,
              mirrorMarginsDefault: mirrorMarginsDefault,
            );
            sections.add(SectionModel(
              pageWidthDxa: sec.pageWidthDxa,
              pageHeightDxa: sec.pageHeightDxa,
              marginTopDxa: sec.marginTopDxa,
              marginBottomDxa: sec.marginBottomDxa,
              marginLeftDxa: sec.marginLeftDxa,
              marginRightDxa: sec.marginRightDxa,
              headerDistanceDxa: sec.headerDistanceDxa,
              footerDistanceDxa: sec.footerDistanceDxa,
              differentFirstPage: sec.differentFirstPage,
              differentOddEven: sec.differentOddEven,
              mirrorMargins: sec.mirrorMargins,
              defaultHeader: sec.defaultHeader,
              firstPageHeader: sec.firstPageHeader,
              evenHeader: sec.evenHeader,
              defaultFooter: sec.defaultFooter,
              firstPageFooter: sec.firstPageFooter,
              evenFooter: sec.evenFooter,
              blocks: List.of(currentBlocks),
            ));
            currentBlocks = <dynamic>[];
          }
          break;
        case 'tbl':
          currentBlocks.add(parseTable(
            element,
            styles: styles,
            numbering: numbering,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
            theme: theme,
          ));
          break;
        case 'sectPr':
          final sec = _parseSection(
            element,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
            readFile: readFile,
            styles: styles,
            numbering: numbering,
            abstractNumbering: abstractNumbering,
            theme: theme,
            differentOddEvenDefault: differentOddEvenDefault,
            mirrorMarginsDefault: mirrorMarginsDefault,
          );
          sections.add(SectionModel(
            pageWidthDxa: sec.pageWidthDxa,
            pageHeightDxa: sec.pageHeightDxa,
            marginTopDxa: sec.marginTopDxa,
            marginBottomDxa: sec.marginBottomDxa,
            marginLeftDxa: sec.marginLeftDxa,
            marginRightDxa: sec.marginRightDxa,
            headerDistanceDxa: sec.headerDistanceDxa,
            footerDistanceDxa: sec.footerDistanceDxa,
            differentFirstPage: sec.differentFirstPage,
            differentOddEven: sec.differentOddEven,
            mirrorMargins: sec.mirrorMargins,
            defaultHeader: sec.defaultHeader,
            firstPageHeader: sec.firstPageHeader,
            evenHeader: sec.evenHeader,
            defaultFooter: sec.defaultFooter,
            firstPageFooter: sec.firstPageFooter,
            evenFooter: sec.evenFooter,
            blocks: List.of(currentBlocks),
          ));
          currentBlocks = <dynamic>[];
          break;
        default:
          break;
      }
    }

    if (currentBlocks.isNotEmpty || sections.isEmpty) {
      sections.add(SectionModel(
        pageWidthDxa: 11906,
        pageHeightDxa: 16838,
        marginTopDxa: 1440,
        marginBottomDxa: 1440,
        marginLeftDxa: 1440,
        marginRightDxa: 1440,
        headerDistanceDxa: 720,
        footerDistanceDxa: 720,
        differentOddEven: differentOddEvenDefault,
        mirrorMargins: mirrorMarginsDefault,
        blocks: currentBlocks,
      ));
    }

    return DocumentModel(
      sections: sections,
      styles: styles,
      numbering: numbering,
      abstractNumbering: abstractNumbering,
      theme: theme,
    );
  }

  // ---------------------------------------------------------------------------
  // Paragraph parsing
  // ---------------------------------------------------------------------------
  static ParagraphModel parseParagraph(
    XmlElement element, {
    Map<String, StyleModel>? styles,
    Map<String, NumberingDefinition>? numbering,
    Map<String, String>? relationships,
    Uint8List? Function(String path)? readBinaryFile,
    ThemeModel? theme,
  }) {
    styles ??= {};
    numbering ??= {};
    final pPr = element.getElementNS('pPr');
    final styleId = pPr?.getElementNS('pStyle')?.getAttributeNS('val');
    final alignmentVal = pPr?.getElementNS('jc')?.getAttributeNS('val');
    final alignment = alignmentVal != null ? _parseAlignment(alignmentVal) : null;
    final spacingBefore = pPr?.getElementNS('spacing')?.getAttributeNS('before') != null
        ? int.tryParse(pPr!.getElementNS('spacing')!.getAttributeNS('before')!)
        : null;
    final spacingAfter = pPr?.getElementNS('spacing')?.getAttributeNS('after') != null
        ? int.tryParse(pPr!.getElementNS('spacing')!.getAttributeNS('after')!)
        : null;
    final line = pPr?.getElementNS('spacing')?.getAttributeNS('line') != null
        ? int.tryParse(pPr!.getElementNS('spacing')!.getAttributeNS('line')!)
        : null;
    final lineRuleVal = pPr?.getElementNS('spacing')?.getAttributeNS('lineRule');
    final lineRule = lineRuleVal != null ? _parseLineRule(lineRuleVal) : null;
    final ind = pPr?.getElementNS('ind');
    final indentLeft = ind?.getAttributeNS('left') != null ? int.tryParse(ind!.getAttributeNS('left')!) : null;
    final indentRight = ind?.getAttributeNS('right') != null ? int.tryParse(ind!.getAttributeNS('right')!) : null;
    final firstLine = ind?.getAttributeNS('firstLine') != null ? int.tryParse(ind!.getAttributeNS('firstLine')!) : null;
    final indentHanging = ind?.getAttributeNS('hanging') != null ? int.tryParse(ind!.getAttributeNS('hanging')!) : null;
    final pageBreakBefore = pPr?.getElementNS('pageBreakBefore') != null ? true : null;
    final keepWithNext = pPr?.getElementNS('keepNext') != null ? true : null;
    final keepLines = pPr?.getElementNS('keepLines') != null ? true : null;
    final contextualSpacing = pPr?.getElementNS('contextualSpacing') != null ? true : null;
    final outlineLevel = int.tryParse(pPr?.getElementNS('outlineLvl')?.getAttributeNS('val') ?? '');

    // Bidi paragraph direction
    final bidi = _parseTriStateBool(pPr?.getElementNS('bidi'));

    // Numbering
    final numPr = pPr?.getElementNS('numPr');
    NumberingReference? numberingRef;
    if (numPr != null) {
      final numId = numPr.getElementNS('numId')?.getAttributeNS('val');
      final ilvl = int.tryParse(numPr.getElementNS('ilvl')?.getAttributeNS('val') ?? '0') ?? 0;
      if (numId != null) numberingRef = NumberingReference(numId: numId, ilvl: ilvl);
    }

    // Paragraph shading
    Color? shading;
    final shdElem = pPr?.getElementNS('shd');
    if (shdElem != null) {
      final fill = shdElem.getAttributeNS('fill');
      final themeColor = shdElem.getAttributeNS('themeColor');
      final themeTint = shdElem.getAttributeNS('themeTint');
      final themeShade = shdElem.getAttributeNS('themeShade');
      if ((fill != null && fill.toLowerCase() != 'auto') || themeColor != null) {
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
        shading = ColorResolver.resolve(
          hexValue: fill,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Paragraph borders
    Map<String, dynamic>? borders;
    final pBdr = pPr?.getElementNS('pBdr');
    if (pBdr != null) {
      borders = _parseBorders(pBdr);
    }

    // Tab stops
    final tabStops = <dynamic>[];
    final tabs = pPr?.getElementNS('tabs');
    if (tabs != null) {
      for (final tab in tabs.children.whereType<XmlElement>()) {
        if (tab.name.local == 'tab') {
          tabStops.add({
            'val': tab.getAttributeNS('val') ?? 'left',
            'pos': int.tryParse(tab.getAttributeNS('pos') ?? '0') ?? 0,
          });
        }
      }
    }

    // Default run properties from pPr/rPr
    Map<String, dynamic>? defaultRunProperties;
    final pPrRpr = pPr?.getElementNS('rPr');
    if (pPrRpr != null) {
      defaultRunProperties = _parseRunPropertiesMap(pPrRpr, theme);
    }

    // Stateful recursive extraction of runs under the paragraph element
    final runs = <RunModel>[];
    String? activeFieldCode;
    bool inFieldSeparate = false;

    void parseElement(XmlElement parent) {
      for (final child in parent.children.whereType<XmlElement>()) {
        final name = child.name.local;
        if (name == 'r') {
          final run = _parseRun(
            child,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
            theme: theme,
          );

          // Check for fldChar inside run
          final fldChar = child.getElementNS('fldChar');
          if (fldChar != null) {
            final type = fldChar.getAttributeNS('type');
            if (type == 'begin') {
              inFieldSeparate = false;
            } else if (type == 'separate') {
              inFieldSeparate = true;
            } else if (type == 'end') {
              activeFieldCode = null;
              inFieldSeparate = false;
            }
          }

          // Check for instrText inside run
          final instrText = child.getElementNS('instrText');
          if (instrText != null) {
            activeFieldCode = instrText.innerText.trim().toUpperCase();
          }

          // If we are in the separate section of a field, this run displays the field's cached value
          if (inFieldSeparate && activeFieldCode != null) {
            final baseField = activeFieldCode!.split(' ').first;
            runs.add(run.copyWithFieldCode(baseField));
          } else {
            // Only add the run if it's not the instruction text (which is not meant to be displayed)
            if (instrText == null) {
              runs.add(run);
            }
          }
        } else if (name == 'hyperlink') {
          final rId = child.getAttributeNS('id') ?? child.getAttributeNS('r:id');
          final anchor = child.getAttributeNS('anchor');

          final hyperRuns = <RunModel>[];
          for (final gChild in child.descendants.whereType<XmlElement>()) {
            if (gChild.name.local == 'r') {
              final run = _parseRun(
                gChild,
                relationships: relationships,
                readBinaryFile: readBinaryFile,
                theme: theme,
              );
              hyperRuns.add(run.copyWithHyperlink(rId: rId, anchor: anchor));
            }
          }
          runs.addAll(hyperRuns);
        } else if (name == 'fldSimple') {
          final instr = child.getAttributeNS('instr')?.trim().toUpperCase();
          final baseField = instr != null ? instr.split(' ').first : null;
          final simpleRuns = <RunModel>[];
          for (final gChild in child.descendants.whereType<XmlElement>()) {
            if (gChild.name.local == 'r') {
              final run = _parseRun(
                gChild,
                relationships: relationships,
                readBinaryFile: readBinaryFile,
                theme: theme,
              );
              simpleRuns.add(run.copyWithFieldCode(baseField));
            }
          }
          runs.addAll(simpleRuns);
        } else if (name == 'sdt' || name == 'sdtContent' || name == 'ins' || name == 'del') {
          parseElement(child);
        }
      }
    }

    parseElement(element);

    return ParagraphModel(
      styleId: styleId,
      alignment: alignment,
      spacingBeforeDxa: spacingBefore,
      spacingAfterDxa: spacingAfter,
      lineSpacingValue: line,
      lineSpacingRule: lineRule,
      indentLeftDxa: indentLeft,
      indentRightDxa: indentRight,
      indentFirstLineDxa: firstLine,
      indentHangingDxa: indentHanging,
      keepWithNext: keepWithNext,
      keepLines: keepLines,
      pageBreakBefore: pageBreakBefore,
      contextualSpacing: contextualSpacing,
      outlineLevel: outlineLevel,
      numbering: numberingRef,
      shading: shading,
      borders: borders,
      customTabStops: tabStops,
      defaultRunProperties: defaultRunProperties,
      runs: runs,
      bidi: bidi,
    );
  }

  // ---------------------------------------------------------------------------
  // Run parsing
  // ---------------------------------------------------------------------------
  static RunModel _parseRun(
    XmlElement runElement, {
    Map<String, String>? relationships,
    Uint8List? Function(String path)? readBinaryFile,
    ThemeModel? theme,
  }) {
    final rPr = runElement.getElementNS('rPr');

    final rFonts = rPr?.getElementNS('rFonts');
    final ascii = rFonts?.getAttributeNS('ascii');
    final hAnsi = rFonts?.getAttributeNS('hAnsi');
    final cs = rFonts?.getAttributeNS('cs');
    
    final asciiTheme = rFonts?.getAttributeNS('asciiTheme');
    final hAnsiTheme = rFonts?.getAttributeNS('hAnsiTheme');
    final cstheme = rFonts?.getAttributeNS('cstheme');

    String? fontAscii = ascii;
    if (asciiTheme != null && theme != null) {
      fontAscii = theme.resolveThemeFont(asciiTheme) ?? ascii;
    }

    String? fontHAnsi = hAnsi;
    if (hAnsiTheme != null && theme != null) {
      fontHAnsi = theme.resolveThemeFont(hAnsiTheme) ?? hAnsi;
    }

    String? fontCS = cs;
    if (cstheme != null && theme != null) {
      fontCS = theme.resolveThemeFont(cstheme) ?? cs;
    }
    final rStyle = rPr?.getElementNS('rStyle')?.getAttributeNS('val');
    final fontSize = int.tryParse(rPr?.getElementNS('sz')?.getAttributeNS('val') ?? '');

    // Three-state booleans: present without val or val="true"/"1" = true, val="0"/"false" = false, absent = null
    final bold = _parseTriStateBool(rPr?.getElementNS('b'));
    final italic = _parseTriStateBool(rPr?.getElementNS('i'));
    final boldCs = _parseTriStateBool(rPr?.getElementNS('bCs'));
    final italicCs = _parseTriStateBool(rPr?.getElementNS('iCs'));
    final rtl = _parseTriStateBool(rPr?.getElementNS('rtl'));
    final strikethrough = _parseTriStateBool(rPr?.getElementNS('strike'));
    final doubleStrikethrough = _parseTriStateBool(rPr?.getElementNS('dstrike'));
    final allCaps = _parseTriStateBool(rPr?.getElementNS('caps'));
    final smallCaps = _parseTriStateBool(rPr?.getElementNS('smallCaps'));
    final shadow = _parseTriStateBool(rPr?.getElementNS('shadow'));
    final outline = _parseTriStateBool(rPr?.getElementNS('outline'));
    final vanish = _parseTriStateBool(rPr?.getElementNS('vanish'));

    final uElem = rPr?.getElementNS('u');
    final underline = uElem != null ? _parseUnderline(uElem.getAttributeNS('val') ?? 'single') : null;
    Color? underlineColor;
    if (uElem != null) {
      final uColorVal = uElem.getAttributeNS('color');
      final uThemeColor = uElem.getAttributeNS('themeColor');
      final uThemeTint = uElem.getAttributeNS('themeTint');
      final uThemeShade = uElem.getAttributeNS('themeShade');
      if (uColorVal != null || uThemeColor != null) {
        double? tint;
        if (uThemeTint != null) {
          final val = int.tryParse(uThemeTint, radix: 16);
          if (val != null) tint = val / 255.0;
        }
        double? shade;
        if (uThemeShade != null) {
          final val = int.tryParse(uThemeShade, radix: 16);
          if (val != null) shade = val / 255.0;
        }
        underlineColor = ColorResolver.resolve(
          hexValue: uColorVal,
          themeColor: uThemeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Color
    Color? color;
    final colorElem = rPr?.getElementNS('color');
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
        color = ColorResolver.resolve(
          hexValue: colorVal,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
          isAutoText: true,
        );
      }
    }

    // Highlight
    Color? highlight;
    final highlightVal = rPr?.getElementNS('highlight')?.getAttributeNS('val');
    if (highlightVal != null) {
      final hex = _highlightColorMap[highlightVal];
      if (hex != null) {
        highlight = ColorResolver.resolve(hexValue: hex, theme: theme);
      }
    }

    // Background shading
    Color? background;
    final shdElem = rPr?.getElementNS('shd');
    if (shdElem != null) {
      final fill = shdElem.getAttributeNS('fill');
      final themeColor = shdElem.getAttributeNS('themeColor');
      final themeTint = shdElem.getAttributeNS('themeTint');
      final themeShade = shdElem.getAttributeNS('themeShade');
      if ((fill != null && fill.toLowerCase() != 'auto') || themeColor != null) {
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
        background = ColorResolver.resolve(
          hexValue: fill,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Vertical alignment
    VerticalAlignment? vertAlign;
    final vertAlignVal = rPr?.getElementNS('vertAlign')?.getAttributeNS('val');
    if (vertAlignVal != null) {
      switch (vertAlignVal) {
        case 'superscript':
          vertAlign = VerticalAlignment.superscript;
          break;
        case 'subscript':
          vertAlign = VerticalAlignment.subscript;
          break;
        default:
          vertAlign = VerticalAlignment.baseline;
      }
    }

    // Character spacing
    int? characterSpacing;
    final spacingElem = rPr?.getElementNS('spacing');
    if (spacingElem != null) {
      characterSpacing = int.tryParse(spacingElem.getAttributeNS('val') ?? '');
    }

    // Iterate DIRECT children of <w:r> (NOT findAllElements which is recursive!)
    final textParts = <String>[];
    RunType runType = RunType.text;
    ImageModel? imageModel;
    String? symbolFont;
    int? symbolCharCode;

    for (final child in runElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 't':
          textParts.add(child.innerText);
          break;
        case 'tab':
          runType = RunType.tab;
          break;
        case 'br':
          final brType = child.getAttributeNS('type');
          if (brType == 'page') {
            runType = RunType.pageBreak;
          } else {
            runType = RunType.lineBreak;
          }
          break;
        case 'sym':
          runType = RunType.symbol;
          symbolFont = child.getAttributeNS('font');
          final charHex = child.getAttributeNS('char');
          if (charHex != null) {
            symbolCharCode = int.tryParse(charHex, radix: 16);
          }
          break;
        case 'drawing':
          final parsed = _parseDrawing(
            child,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
          );
          if (parsed != null) {
            runType = RunType.image;
            imageModel = parsed;
          }
          break;
        default:
          break;
      }
    }

    final text = textParts.join();

    return RunModel(
      text: text,
      type: runType,
      fontAscii: fontAscii,
      fontHAnsi: fontHAnsi,
      fontCS: fontCS,
      rStyle: rStyle,
      fontSizeHalfPt: fontSize,
      bold: bold,
      italic: italic,
      boldCs: boldCs,
      italicCs: italicCs,
      rtl: rtl,
      underline: underline != UnderlineType.none ? underline : null,
      underlineColor: underlineColor,
      strikethrough: strikethrough,
      doubleStrikethrough: doubleStrikethrough,
      color: color,
      highlight: highlight,
      background: background,
      vertAlign: vertAlign,
      allCaps: allCaps,
      smallCaps: smallCaps,
      shadow: shadow,
      outline: outline,
      vanish: vanish,
      characterSpacingTwentieths: characterSpacing,
      image: imageModel,
      symbolFont: symbolFont,
      symbolCharCode: symbolCharCode,
    );
  }

  // ---------------------------------------------------------------------------
  // Drawing / Image parsing
  // ---------------------------------------------------------------------------
  static ImageModel? _parseDrawing(
    XmlElement drawingElement, {
    Map<String, String>? relationships,
    Uint8List? Function(String path)? readBinaryFile,
  }) {
    // Look for wp:inline or wp:anchor
    XmlElement? container;
    String? wrapType;
    int? positionXEmu;
    int? positionYEmu;
    String? relativeFromH;
    String? alignH;
    String? relativeFromV;
    String? alignV;

    for (final child in drawingElement.children.whereType<XmlElement>()) {
      if (child.name.local == 'inline') {
        container = child;
        wrapType = 'inline';
        break;
      } else if (child.name.local == 'anchor') {
        container = child;
        wrapType = 'anchor';

        // Extract positioning
        final posH = child.getElementNS('positionH');
        final posV = child.getElementNS('positionV');
        if (posH != null) {
          relativeFromH = posH.getAttributeNS('relativeFrom');
          alignH = posH.getElementNS('align')?.innerText;
          positionXEmu = int.tryParse(posH.getElementNS('posOffset')?.innerText ?? '');
        }
        if (posV != null) {
          relativeFromV = posV.getAttributeNS('relativeFrom');
          alignV = posV.getElementNS('align')?.innerText;
          positionYEmu = int.tryParse(posV.getElementNS('posOffset')?.innerText ?? '');
        }

        // Determine wrap type from child elements
        for (final wrapChild in child.children.whereType<XmlElement>()) {
          switch (wrapChild.name.local) {
            case 'wrapNone':
              wrapType = 'none';
              break;
            case 'wrapSquare':
              wrapType = 'square';
              break;
            case 'wrapTight':
              wrapType = 'tight';
              break;
            case 'wrapThrough':
              wrapType = 'through';
              break;
            case 'wrapTopAndBottom':
              wrapType = 'topAndBottom';
              break;
          }
        }
        break;
      }
    }

    if (container == null) return null;

    // Extract extent (EMU dimensions)
    final extent = container.getElementNS('extent');
    final widthEmu = int.tryParse(extent?.getAttributeNS('cx') ?? '0') ?? 0;
    final heightEmu = int.tryParse(extent?.getAttributeNS('cy') ?? '0') ?? 0;

    // Find a:blip r:embed
    final rId = _findBlipEmbed(container);
    if (rId == null || relationships == null || readBinaryFile == null) return null;

    final target = relationships[rId];
    if (target == null) return null;

    // Resolve path relative to word/ directory
    final imagePath = resolveZipPath(target);
    final bytes = readBinaryFile(imagePath);
    if (bytes == null) return null;

    return ImageModel(
      bytes: bytes,
      widthEmu: widthEmu,
      heightEmu: heightEmu,
      wrapType: wrapType,
      positionXEmu: positionXEmu,
      positionYEmu: positionYEmu,
      relativeFromH: relativeFromH,
      alignH: alignH,
      relativeFromV: relativeFromV,
      alignV: alignV,
    );
  }

  static String? _findBlipEmbed(XmlElement element) {
    // Recursively find a:blip element and get r:embed attribute
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local == 'blip') {
        // Try r:embed attribute (may have namespace prefix)
        final embed = child.getAttributeNS('embed') ?? child.getAttributeNS('r:embed');
        if (embed != null) return embed;
      }
      final result = _findBlipEmbed(child);
      if (result != null) return result;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Table parsing
  // ---------------------------------------------------------------------------
  static TableModel parseTable(
    XmlElement element, {
    Map<String, StyleModel>? styles,
    Map<String, NumberingDefinition>? numbering,
    Map<String, String>? relationships,
    Uint8List? Function(String path)? readBinaryFile,
    ThemeModel? theme,
  }) {
    // Parse tblPr
    final tblPr = element.getElementNS('tblPr');
    final tblW = tblPr?.getElementNS('tblW');
    int totalWidthDxa = int.tryParse(tblW?.getAttributeNS('w') ?? '0') ?? 0;
    final tblAlignment = _parseTableAlignment(tblPr?.getElementNS('jc')?.getAttributeNS('val'));

    // Table borders
    Map<String, dynamic>? tblBorders;
    final tblBdrElem = tblPr?.getElementNS('tblBorders');
    if (tblBdrElem != null) {
      tblBorders = _parseBorders(tblBdrElem);
    }

    // Default cell margins
    Map<String, int>? defaultCellMargins;
    final tblCellMar = tblPr?.getElementNS('tblCellMar');
    if (tblCellMar != null) {
      defaultCellMargins = _parseCellMargins(tblCellMar);
    }

    // Parse tblGrid
    final columnWidthsDxa = <int>[];
    final tblGrid = element.getElementNS('tblGrid');
    if (tblGrid != null) {
      for (final gridCol in tblGrid.children.whereType<XmlElement>()) {
        if (gridCol.name.local == 'gridCol') {
          columnWidthsDxa.add(int.tryParse(gridCol.getAttributeNS('w') ?? '0') ?? 0);
        }
      }
    }

    // If totalWidthDxa is 0, compute from grid columns
    if (totalWidthDxa == 0 && columnWidthsDxa.isNotEmpty) {
      totalWidthDxa = columnWidthsDxa.fold(0, (sum, w) => sum + w);
    }

    // Parse rows — iterate direct children only
    final rows = <TableRowModel>[];
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local == 'tr') {
        rows.add(_parseTableRow(
          child,
          styles: styles,
          numbering: numbering,
          relationships: relationships,
          readBinaryFile: readBinaryFile,
          theme: theme,
        ));
      }
    }

    return TableModel(
      totalWidthDxa: totalWidthDxa,
      alignment: tblAlignment,
      columnWidthsDxa: columnWidthsDxa,
      borders: tblBorders,
      defaultCellMargins: defaultCellMargins,
      rows: rows,
    );
  }

  static TableRowModel _parseTableRow(
    XmlElement trElement, {
    Map<String, StyleModel>? styles,
    Map<String, NumberingDefinition>? numbering,
    Map<String, String>? relationships,
    Uint8List? Function(String path)? readBinaryFile,
    ThemeModel? theme,
  }) {
    final trPr = trElement.getElementNS('trPr');
    int? heightDxa;
    HeightRule heightRule = HeightRule.auto;
    bool isHeader = false;
    bool cantSplit = false;

    if (trPr != null) {
      final trHeight = trPr.getElementNS('trHeight');
      if (trHeight != null) {
        heightDxa = int.tryParse(trHeight.getAttributeNS('val') ?? '');
        final hRule = trHeight.getAttributeNS('hRule');
        if (hRule == 'exact') {
          heightRule = HeightRule.exact;
        } else if (hRule == 'atLeast') {
          heightRule = HeightRule.atLeast;
        }
      }
      isHeader = trPr.getElementNS('tblHeader') != null;
      cantSplit = trPr.getElementNS('cantSplit') != null;
    }

    // Parse cells — direct children only
    final cells = <TableCellModel>[];
    for (final child in trElement.children.whereType<XmlElement>()) {
      if (child.name.local == 'tc') {
        cells.add(_parseTableCell(
          child,
          styles: styles,
          numbering: numbering,
          relationships: relationships,
          readBinaryFile: readBinaryFile,
          theme: theme,
        ));
      }
    }

    return TableRowModel(
      heightDxa: heightDxa,
      heightRule: heightRule,
      isHeader: isHeader,
      cantSplit: cantSplit,
      cells: cells,
    );
  }

  static TableCellModel _parseTableCell(
    XmlElement tcElement, {
    Map<String, StyleModel>? styles,
    Map<String, NumberingDefinition>? numbering,
    Map<String, String>? relationships,
    Uint8List? Function(String path)? readBinaryFile,
    ThemeModel? theme,
  }) {
    final tcPr = tcElement.getElementNS('tcPr');
    final widthDxa = int.tryParse(tcPr?.getElementNS('tcW')?.getAttributeNS('w') ?? '0') ?? 0;
    final gridSpan = int.tryParse(tcPr?.getElementNS('gridSpan')?.getAttributeNS('val') ?? '1') ?? 1;

    // vMerge
    VerticalMergeType? vMerge;
    final vMergeElem = tcPr?.getElementNS('vMerge');
    if (vMergeElem != null) {
      final vMergeVal = vMergeElem.getAttributeNS('val');
      if (vMergeVal == 'restart') {
        vMerge = VerticalMergeType.restart;
      } else {
        vMerge = VerticalMergeType.continueMerge;
      }
    }

    // Cell borders
    Map<String, dynamic>? tcBorders;
    final tcBdrElem = tcPr?.getElementNS('tcBorders');
    if (tcBdrElem != null) {
      tcBorders = _parseBorders(tcBdrElem);
    }
    
    // Cell shading
    Color? cellShading;
    final tcShdElem = tcPr?.getElementNS('shd');
    if (tcShdElem != null) {
      final fill = tcShdElem.getAttributeNS('fill');
      final themeColor = tcShdElem.getAttributeNS('themeColor');
      final themeTint = tcShdElem.getAttributeNS('themeTint');
      final themeShade = tcShdElem.getAttributeNS('themeShade');
      if ((fill != null && fill.toLowerCase() != 'auto') || themeColor != null) {
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
        cellShading = ColorResolver.resolve(
          hexValue: fill,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Vertical alignment
    VerticalAlignment vAlign = VerticalAlignment.baseline;
    final vAlignVal = tcPr?.getElementNS('vAlign')?.getAttributeNS('val');
    if (vAlignVal == 'center') {
      vAlign = VerticalAlignment.baseline; // Map to available enum
    } else if (vAlignVal == 'bottom') {
      vAlign = VerticalAlignment.subscript; // Approximate mapping
    }

    // Cell margins
    Map<String, int>? tcMar;
    final tcMarElem = tcPr?.getElementNS('tcMar');
    if (tcMarElem != null) {
      tcMar = _parseCellMargins(tcMarElem);
    }

    // Parse cell paragraphs — use full parseParagraph, direct children only
    final paragraphs = <ParagraphModel>[];
    for (final child in tcElement.children.whereType<XmlElement>()) {
      if (child.name.local == 'p') {
        paragraphs.add(parseParagraph(
          child,
          styles: styles,
          numbering: numbering,
          relationships: relationships,
          readBinaryFile: readBinaryFile,
          theme: theme,
        ));
      }
    }

    return TableCellModel(
      widthDxa: widthDxa,
      gridSpan: gridSpan,
      vMerge: vMerge,
      borders: tcBorders,
      shading: cellShading,
      verticalAlignment: vAlign,
      margins: tcMar,
      paragraphs: paragraphs,
    );
  }

  // ---------------------------------------------------------------------------
  // Section parsing
  // ---------------------------------------------------------------------------
  static SectionModel _parseSection(
    XmlElement sectPr, {
    Map<String, String>? relationships,
    Uint8List? Function(String path)? readBinaryFile,
    String? Function(String path)? readFile,
    required Map<String, StyleModel> styles,
    required Map<String, NumberingDefinition> numbering,
    required Map<String, AbstractNumDefinition> abstractNumbering,
    required ThemeModel? theme,
    required bool differentOddEvenDefault,
    required bool mirrorMarginsDefault,
  }) {
    final pgSz = sectPr.getElementNS('pgSz');
    final pgMar = sectPr.getElementNS('pgMar');

    final orient = pgSz?.getAttributeNS('orient');
    var pageWidthDxa = int.tryParse(pgSz?.getAttributeNS('w') ?? '11906') ?? 11906;
    var pageHeightDxa = int.tryParse(pgSz?.getAttributeNS('h') ?? '16838') ?? 16838;
    if (orient == 'landscape' && pageWidthDxa < pageHeightDxa) {
      final temp = pageWidthDxa;
      pageWidthDxa = pageHeightDxa;
      pageHeightDxa = temp;
    }

    final marginTopDxa = int.tryParse(pgMar?.getAttributeNS('top') ?? '1440') ?? 1440;
    final marginBottomDxa = int.tryParse(pgMar?.getAttributeNS('bottom') ?? '1440') ?? 1440;
    final gutterDxa = int.tryParse(pgMar?.getAttributeNS('gutter') ?? '0') ?? 0;
    final marginLeftDxa = (int.tryParse(pgMar?.getAttributeNS('left') ?? '1440') ?? 1440) + gutterDxa;
    final marginRightDxa = int.tryParse(pgMar?.getAttributeNS('right') ?? '1440') ?? 1440;
    final headerDistanceDxa = int.tryParse(pgMar?.getAttributeNS('header') ?? '720') ?? 720;
    final footerDistanceDxa = int.tryParse(pgMar?.getAttributeNS('footer') ?? '720') ?? 720;

    // Parse titlePg
    final differentFirstPage = sectPr.getElementNS('titlePg') != null;
    var differentOddEven = differentOddEvenDefault;

    // Parse header/footer references
    HeaderFooterModel? defaultHeader;
    HeaderFooterModel? firstPageHeader;
    HeaderFooterModel? evenHeader;
    HeaderFooterModel? defaultFooter;
    HeaderFooterModel? firstPageFooter;
    HeaderFooterModel? evenFooter;

    if (relationships != null && readFile != null && readBinaryFile != null) {
      for (final child in sectPr.children.whereType<XmlElement>()) {
        if (child.name.local == 'headerReference') {
          final type = child.getAttributeNS('type');
          final rId = child.getAttributeNS('id') ?? child.getAttributeNS('r:id');
          if (rId != null) {
            final target = relationships[rId];
            if (target != null) {
              final headerPath = resolveZipPath(target);
              final headerXml = readFile(headerPath);
              if (headerXml != null) {
                final headerModel = HeaderFooterParser.parse(
                  headerXml,
                  styles: styles,
                  numbering: numbering,
                  abstractNumbering: abstractNumbering,
                  theme: theme,
                  relationships: relationships,
                  readBinaryFile: readBinaryFile,
                );
                if (type == 'first') {
                  firstPageHeader = headerModel;
                } else if (type == 'even') {
                  evenHeader = headerModel;
                  differentOddEven = true;
                } else {
                  defaultHeader = headerModel;
                }
              }
            }
          }
        } else if (child.name.local == 'footerReference') {
          final type = child.getAttributeNS('type');
          final rId = child.getAttributeNS('id') ?? child.getAttributeNS('r:id');
          if (rId != null) {
            final target = relationships[rId];
            if (target != null) {
              final footerPath = resolveZipPath(target);
              final footerXml = readFile(footerPath);
              if (footerXml != null) {
                final footerModel = HeaderFooterParser.parse(
                  footerXml,
                  styles: styles,
                  numbering: numbering,
                  abstractNumbering: abstractNumbering,
                  theme: theme,
                  relationships: relationships,
                  readBinaryFile: readBinaryFile,
                );
                if (type == 'first') {
                  firstPageFooter = footerModel;
                } else if (type == 'even') {
                  evenFooter = footerModel;
                  differentOddEven = true;
                } else {
                  defaultFooter = footerModel;
                }
              }
            }
          }
        }
      }
    }

    return SectionModel(
      pageWidthDxa: pageWidthDxa,
      pageHeightDxa: pageHeightDxa,
      marginTopDxa: marginTopDxa,
      marginBottomDxa: marginBottomDxa,
      marginLeftDxa: marginLeftDxa,
      marginRightDxa: marginRightDxa,
      headerDistanceDxa: headerDistanceDxa,
      footerDistanceDxa: footerDistanceDxa,
      differentFirstPage: differentFirstPage,
      differentOddEven: differentOddEven,
      mirrorMargins: mirrorMarginsDefault,
      defaultHeader: defaultHeader,
      firstPageHeader: firstPageHeader,
      evenHeader: evenHeader,
      defaultFooter: defaultFooter,
      firstPageFooter: firstPageFooter,
      evenFooter: evenFooter,
    );
  }

  // ---------------------------------------------------------------------------
  // Run properties map (for default run properties in paragraph pPr)
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> _parseRunPropertiesMap(XmlElement rPr, ThemeModel? theme) {
    final result = <String, dynamic>{};
    // Fonts
    final rFonts = rPr.getElementNS('rFonts');
    if (rFonts != null) {
      final ascii = rFonts.getAttributeNS('ascii');
      final hAnsi = rFonts.getAttributeNS('hAnsi');
      final cs = rFonts.getAttributeNS('cs');
      
      final asciiTheme = rFonts.getAttributeNS('asciiTheme');
      final hAnsiTheme = rFonts.getAttributeNS('hAnsiTheme');
      final cstheme = rFonts.getAttributeNS('cstheme');

      String? resolvedAscii = ascii;
      if (asciiTheme != null && theme != null) {
        resolvedAscii = theme.resolveThemeFont(asciiTheme) ?? ascii;
      }

      String? resolvedHAnsi = hAnsi;
      if (hAnsiTheme != null && theme != null) {
        resolvedHAnsi = theme.resolveThemeFont(hAnsiTheme) ?? hAnsi;
      }

      String? resolvedCS = cs;
      if (cstheme != null && theme != null) {
        resolvedCS = theme.resolveThemeFont(cstheme) ?? cs;
      }

      if (resolvedAscii != null) result['fontAscii'] = resolvedAscii;
      if (resolvedHAnsi != null) result['fontHAnsi'] = resolvedHAnsi;
      if (resolvedCS != null) result['fontCS'] = resolvedCS;
    }

    // Font size
    final sz = rPr.getElementNS('sz')?.getAttributeNS('val');
    if (sz != null) result['fontSize'] = int.tryParse(sz);

    // Bold (three-state)
    final bElem = rPr.getElementNS('b');
    if (bElem != null) {
      final bVal = bElem.getAttributeNS('val');
      result['bold'] = (bVal == null || (bVal != '0' && bVal != 'false'));
    }

    // Bold CS
    final bCsElem = rPr.getElementNS('bCs');
    if (bCsElem != null) {
      final bCsVal = bCsElem.getAttributeNS('val');
      result['boldCs'] = (bCsVal == null || (bCsVal != '0' && bCsVal != 'false'));
    }

    // Italic (three-state)
    final iElem = rPr.getElementNS('i');
    if (iElem != null) {
      final iVal = iElem.getAttributeNS('val');
      result['italic'] = (iVal == null || (iVal != '0' && iVal != 'false'));
    }

    // Italic CS
    final iCsElem = rPr.getElementNS('iCs');
    if (iCsElem != null) {
      final iCsVal = iCsElem.getAttributeNS('val');
      result['italicCs'] = (iCsVal == null || (iCsVal != '0' && iCsVal != 'false'));
    }

    // RTL run
    final rtlElem = rPr.getElementNS('rtl');
    if (rtlElem != null) {
      final rtlVal = rtlElem.getAttributeNS('val');
      result['rtl'] = (rtlVal == null || (rtlVal != '0' && rtlVal != 'false'));
    }

    // Underline
    final uElem = rPr.getElementNS('u');
    if (uElem != null) {
      result['underline'] = _parseUnderline(uElem.getAttributeNS('val') ?? 'single');
      final uColorVal = uElem.getAttributeNS('color');
      final uThemeColor = uElem.getAttributeNS('themeColor');
      final uThemeTint = uElem.getElementNS('themeTint')?.getAttributeNS('val') ?? uElem.getAttributeNS('themeTint');
      final uThemeShade = uElem.getElementNS('themeShade')?.getAttributeNS('val') ?? uElem.getAttributeNS('themeShade');
      if (uColorVal != null || uThemeColor != null) {
        double? tint;
        if (uThemeTint != null) {
          final val = int.tryParse(uThemeTint, radix: 16);
          if (val != null) tint = val / 255.0;
        }
        double? shade;
        if (uThemeShade != null) {
          final val = int.tryParse(uThemeShade, radix: 16);
          if (val != null) shade = val / 255.0;
        }
        result['underlineColor'] = ColorResolver.resolve(
          hexValue: uColorVal,
          themeColor: uThemeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Strikethrough
    final strikeElem = rPr.getElementNS('strike');
    if (strikeElem != null) {
      final sVal = strikeElem.getAttributeNS('val');
      result['strike'] = (sVal == null || (sVal != '0' && sVal != 'false'));
    }

    // Double strikethrough
    final dstrikeElem = rPr.getElementNS('dstrike');
    if (dstrikeElem != null) {
      final dsVal = dstrikeElem.getAttributeNS('val');
      result['dstrike'] = (dsVal == null || (dsVal != '0' && dsVal != 'false'));
    }

    // Color
    final colorElem = rPr.getElementNS('color');
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
        result['color'] = ColorResolver.resolve(
          hexValue: colorVal,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
          isAutoText: true,
        );
      }
    }

    // Highlight
    final highlightVal = rPr.getElementNS('highlight')?.getAttributeNS('val');
    if (highlightVal != null) {
      final hex = _highlightColorMap[highlightVal];
      if (hex != null) {
        result['highlight'] = ColorResolver.resolve(hexValue: hex, theme: theme);
      }
    }

    // Shading (background)
    final shd = rPr.getElementNS('shd');
    if (shd != null) {
      final fill = shd.getAttributeNS('fill');
      final themeColor = shd.getAttributeNS('themeColor');
      final themeTint = shd.getAttributeNS('themeTint');
      final themeShade = shd.getAttributeNS('themeShade');
      if ((fill != null && fill.toLowerCase() != 'auto') || themeColor != null) {
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
        result['background'] = ColorResolver.resolve(
          hexValue: fill,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Vertical alignment
    final vertAlignVal = rPr.getElementNS('vertAlign')?.getAttributeNS('val');
    if (vertAlignVal != null) {
      switch (vertAlignVal) {
        case 'superscript':
          result['vertAlign'] = VerticalAlignment.superscript;
          break;
        case 'subscript':
          result['vertAlign'] = VerticalAlignment.subscript;
          break;
        default:
          result['vertAlign'] = VerticalAlignment.baseline;
      }
    }

    // Caps
    final capsElem = rPr.getElementNS('caps');
    if (capsElem != null) {
      final cVal = capsElem.getAttributeNS('val');
      result['caps'] = (cVal == null || (cVal != '0' && cVal != 'false'));
    }

    // Small caps
    final smallCapsElem = rPr.getElementNS('smallCaps');
    if (smallCapsElem != null) {
      final scVal = smallCapsElem.getAttributeNS('val');
      result['smallCaps'] = (scVal == null || (scVal != '0' && scVal != 'false'));
    }

    // Shadow
    final shadowElem = rPr.getElementNS('shadow');
    if (shadowElem != null) {
      final shVal = shadowElem.getAttributeNS('val');
      result['shadow'] = (shVal == null || (shVal != '0' && shVal != 'false'));
    }

    // Outline
    final outlineElem = rPr.getElementNS('outline');
    if (outlineElem != null) {
      final oVal = outlineElem.getAttributeNS('val');
      result['outline'] = (oVal == null || (oVal != '0' && oVal != 'false'));
    }

    // Vanish
    final vanishElem = rPr.getElementNS('vanish');
    if (vanishElem != null) {
      final vVal = vanishElem.getAttributeNS('val');
      result['vanish'] = (vVal == null || (vVal != '0' && vVal != 'false'));
    }

    // Character spacing
    final spacingElem = rPr.getElementNS('spacing');
    if (spacingElem != null) {
      final spacingVal = spacingElem.getAttributeNS('val');
      if (spacingVal != null) {
        result['characterSpacing'] = int.tryParse(spacingVal);
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static bool? _parseTriStateBool(XmlElement? element) {
    if (element == null) return null;
    final val = element.getAttributeNS('val');
    if (val == null) return true;
    if (val == '0' || val == 'false') return false;
    return true;
  }

  static Map<String, dynamic> _parseBorders(XmlElement bdrElement) {
    final result = <String, dynamic>{};
    for (final side in ['top', 'bottom', 'left', 'right', 'insideH', 'insideV']) {
      final sideElem = bdrElement.getElementNS(side);
      if (sideElem != null) {
        result[side] = {
          'val': sideElem.getAttributeNS('val') ?? 'none',
          'sz': int.tryParse(sideElem.getAttributeNS('sz') ?? '0') ?? 0,
          'color': sideElem.getAttributeNS('color') ?? 'auto',
          'space': int.tryParse(sideElem.getAttributeNS('space') ?? '0') ?? 0,
        };
      }
    }
    return result;
  }

  static Map<String, int> _parseCellMargins(XmlElement marElement) {
    final result = <String, int>{};
    for (final side in ['top', 'bottom', 'start', 'end', 'left', 'right']) {
      final sideElem = marElement.getElementNS(side);
      if (sideElem != null) {
        result[side] = int.tryParse(sideElem.getAttributeNS('w') ?? '0') ?? 0;
      }
    }
    return result;
  }

  static ParagraphAlignment _parseAlignment(String? value) {
    switch (value) {
      case 'center':
        return ParagraphAlignment.center;
      case 'right':
        return ParagraphAlignment.right;
      case 'both':
        return ParagraphAlignment.both;
      case 'distribute':
        return ParagraphAlignment.distribute;
      default:
        return ParagraphAlignment.left;
    }
  }

  static LineSpacingRule _parseLineRule(String? value) {
    switch (value) {
      case 'exact':
        return LineSpacingRule.exact;
      case 'atLeast':
        return LineSpacingRule.atLeast;
      default:
        return LineSpacingRule.auto;
    }
  }

  static UnderlineType? _parseUnderline(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'none':
        return UnderlineType.none;
      case 'double':
        return UnderlineType.double;
      case 'dotted':
        return UnderlineType.dotted;
      case 'dashed':
        return UnderlineType.dashed;
      case 'wave':
        return UnderlineType.wave;
      default:
        return UnderlineType.single;
    }
  }

  static TableAlignment _parseTableAlignment(String? value) {
    switch (value) {
      case 'center':
        return TableAlignment.center;
      case 'right':
        return TableAlignment.right;
      default:
        return TableAlignment.left;
    }
  }

  /// Simplified paragraph parser (kept for backward compatibility)
  static ParagraphModel parseParagraphSimple(XmlElement pElement) {
    final runs = <RunModel>[];
    for (final child in pElement.children.whereType<XmlElement>()) {
      if (child.name.local == 'r') {
        runs.add(_parseRun(child));
      }
    }
    return ParagraphModel(runs: runs);
  }

  /// Resolves target relationship paths to a clean zip archive path.
  static String resolveZipPath(String target) {
    String resolved = target.replaceAll('\\', '/');
    if (resolved.startsWith('/')) {
      resolved = resolved.substring(1);
    }
    if (!resolved.startsWith('word/')) {
      resolved = 'word/$resolved';
    }
    return resolved;
  }
}

