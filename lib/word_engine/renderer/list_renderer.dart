import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../model/paragraph_model.dart';
import '../model/run_model.dart';
import '../model/style_model.dart';
import '../utils/font_mapper.dart';
import '../utils/style_resolver.dart';
import '../utils/unit_converter.dart';
import 'paragraph_renderer.dart';

class ListRenderer extends StatelessWidget {
  final ParagraphModel paragraph;
  final String labelText;
  final double contentWidth;
  final Map<String, StyleModel> styles;
  /// Numbering level left indent in DXA (twips). 
  /// This is the total indent from the left margin to where the text body starts.
  final int? levelIndentDxa;
  /// Numbering level hanging indent in DXA (twips).
  /// This is the width of the label area (the hanging portion before the text body).
  final int? levelHangingDxa;
  final Map<String, dynamic>? levelRPr;
  final int pageIndex;
  final int totalPages;
  final void Function(String? url, String? anchor)? onHyperlinkTap;

  const ListRenderer({
    super.key,
    required this.paragraph,
    required this.labelText,
    required this.contentWidth,
    required this.styles,
    this.levelIndentDxa,
    this.levelHangingDxa,
    this.levelRPr,
    this.pageIndex = 0,
    this.totalPages = 1,
    this.onHyperlinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveParagraph = StyleResolver.resolveParagraph(paragraph, styles);

    // Determine indentation from numbering level, falling back to paragraph style
    final double totalIndentPx;
    final double hangingPx;
    
    if (levelIndentDxa != null) {
      // Use the numbering level's indent and hanging
      totalIndentPx = UnitConverter.dxaToPx(levelIndentDxa!);
      hangingPx = levelHangingDxa != null 
          ? UnitConverter.dxaToPx(levelHangingDxa!) 
          : 32.0; // fallback label width
    } else if (effectiveParagraph.indentLeftDxa > 0) {
      // Fallback to paragraph-level indent
      totalIndentPx = UnitConverter.dxaToPx(effectiveParagraph.indentLeftDxa);
      hangingPx = effectiveParagraph.indentHangingDxa > 0
          ? UnitConverter.dxaToPx(effectiveParagraph.indentHangingDxa)
          : 32.0;
    } else {
      totalIndentPx = 32.0;
      hangingPx = 32.0;
    }

    // The label area sits at (totalIndent - hanging).
    // Ensure label width has a reasonable minimum (e.g. 36.0 px) to fit multi-digit
    // numbers like "10." or "18." without clipping, while keeping the text body starting at totalIndentPx.
    final double actualLabelWidth = hangingPx < 36.0 ? 36.0 : hangingPx;
    final leftPadding = (totalIndentPx - actualLabelWidth).clamp(0.0, double.infinity);
    final labelWidth = actualLabelWidth;

    // Resolve run styles to style the list label
    final dummyRun = RunModel(text: '');
    final effectiveRunStyle = StyleResolver.resolve(paragraph, dummyRun, styles);
    
    // Merge levelRPr overrides onto effectiveRunStyle fields
    final fontAscii = levelRPr?['fontAscii'] as String? ?? levelRPr?['fontHAnsi'] as String? ?? effectiveRunStyle.fontAscii;
    final fontSizeVal = levelRPr?['fontSize'] as int? ?? effectiveRunStyle.fontSizeHalfPt ?? 22;
    final boldVal = levelRPr?['bold'] as bool? ?? effectiveRunStyle.bold ?? false;
    final italicVal = levelRPr?['italic'] as bool? ?? effectiveRunStyle.italic ?? false;
    final colorVal = levelRPr?['color'] as Color? ?? effectiveRunStyle.color ?? Colors.black;

    final fontFamily = FontMapper.resolve(fontAscii);
    final fontSize = UnitConverter.halfPointToPx(fontSizeVal);

    TextStyle labelStyle;
    try {
      labelStyle = GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        fontWeight: boldVal ? FontWeight.bold : FontWeight.normal,
        fontStyle: italicVal ? FontStyle.italic : FontStyle.normal,
        color: colorVal,
      );
    } catch (_) {
      labelStyle = TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: boldVal ? FontWeight.bold : FontWeight.normal,
        fontStyle: italicVal ? FontStyle.italic : FontStyle.normal,
        color: colorVal,
      );
    }

    // Right indent from paragraph
    final rightPadding = effectiveParagraph.indentRightDxa > 0 
        ? UnitConverter.dxaToPx(effectiveParagraph.indentRightDxa) 
        : 0.0;

    // Create a copy of the paragraph with zeroed-out left indent and hanging
    // to prevent ParagraphRenderer from applying indentation a second time.
    final innerParagraph = paragraph.copyWith(
      indentLeftDxa: () => 0,
      indentHangingDxa: () => 0,
      indentFirstLineDxa: () => 0,
    );

    final listChildren = [
      SizedBox(
        width: labelWidth,
        child: Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Text(
            labelText,
            textAlign: effectiveParagraph.bidi ? TextAlign.left : TextAlign.right,
            textScaleFactor: 1.0,
            style: labelStyle,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
      Expanded(
        child: ParagraphRenderer(
          paragraph: innerParagraph,
          styles: styles,
          contentWidth: (contentWidth - leftPadding - labelWidth - rightPadding).clamp(0.0, double.infinity),
          pageIndex: pageIndex,
          totalPages: totalPages,
          onHyperlinkTap: onHyperlinkTap,
        ),
      ),
    ];

    final childrenOrdered = effectiveParagraph.bidi ? listChildren.reversed.toList() : listChildren;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: childrenOrdered,
      ),
    );
  }
}
