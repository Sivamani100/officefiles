import 'package:flutter/material.dart';

import '../model/paragraph_model.dart';
import '../model/style_model.dart';
import '../utils/color_resolver.dart';
import '../utils/style_resolver.dart';
import '../utils/unit_converter.dart';
import 'run_renderer.dart';

class ParagraphRenderer extends StatelessWidget {
  final ParagraphModel paragraph;
  final Map<String, StyleModel> styles;
  final double contentWidth;
  final int pageIndex;
  final int totalPages;
  final void Function(String? url, String? anchor)? onHyperlinkTap;

  const ParagraphRenderer({
    super.key,
    required this.paragraph,
    required this.styles,
    required this.contentWidth,
    this.pageIndex = 0,
    this.totalPages = 1,
    this.onHyperlinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveParagraph = StyleResolver.resolveParagraph(paragraph, styles);
    final textDirection = effectiveParagraph.bidi ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = _mapAlignment(effectiveParagraph.alignment, effectiveParagraph.bidi);
    
    final leftPadding = effectiveParagraph.indentLeftDxa > 0 
        ? UnitConverter.dxaToPx(effectiveParagraph.indentLeftDxa) 
        : 0.0;
    final rightPadding = effectiveParagraph.indentRightDxa > 0 
        ? UnitConverter.dxaToPx(effectiveParagraph.indentRightDxa) 
        : 0.0;

    final children = <InlineSpan>[];
    for (int runIdx = 0; runIdx < paragraph.runs.length; runIdx++) {
      final run = paragraph.runs[runIdx];
      final effective = StyleResolver.resolve(paragraph, run, styles);
      children.add(RunRenderer.buildRunSpan(
        run,
        effective,
        effectiveParagraph,
        paragraph.runs,
        runIdx,
        pageIndex,
        totalPages,
        paragraph.customTabStops,
        onHyperlinkTap,
      ));
    }

    // First line indent support
    if (effectiveParagraph.indentFirstLineDxa > 0) {
      final firstLineIndentPx = UnitConverter.dxaToPx(effectiveParagraph.indentFirstLineDxa);
      children.insert(0, WidgetSpan(child: SizedBox(width: firstLineIndentPx)));
    }

    Widget result = RichText(
      textScaleFactor: 1.0,
      textAlign: textAlign,
      textDirection: textDirection,
      text: TextSpan(children: children, style: DefaultTextStyle.of(context).style),
    );

    // Paragraph shading and borders
    if (effectiveParagraph.shading != null || effectiveParagraph.borders != null) {
      result = Container(
        decoration: BoxDecoration(
          color: effectiveParagraph.shading,
          border: _buildBorders(effectiveParagraph.borders),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: result,
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentWidth - leftPadding - rightPadding),
        child: result,
      ),
    );
  }

  TextAlign _mapAlignment(ParagraphAlignment alignment, bool bidi) {
    switch (alignment) {
      case ParagraphAlignment.center:
        return TextAlign.center;
      case ParagraphAlignment.right:
        return TextAlign.right;
      case ParagraphAlignment.both:
        return TextAlign.justify;
      case ParagraphAlignment.left:
        return TextAlign.left;
      default:
        return bidi ? TextAlign.right : TextAlign.left;
    }
  }

  Border? _buildBorders(Map<String, dynamic>? borders) {
    if (borders == null) return null;
    BorderSide? getSide(String name) {
      final side = borders[name];
      if (side == null || side['val'] == 'none') return null;
      final sz = side['sz'] as int? ?? 0;
      final width = sz > 0 ? (sz / 8.0 * 96.0 / 72.0) : 1.0;
      final colorHex = side['color'] as String? ?? 'auto';
      final color = colorHex == 'auto' 
          ? Colors.black 
          : ColorResolver.resolve(hexValue: colorHex, theme: null);
      return BorderSide(width: width, color: color, style: BorderStyle.solid);
    }
    
    return Border(
      top: getSide('top') ?? BorderSide.none,
      bottom: getSide('bottom') ?? BorderSide.none,
      left: getSide('left') ?? BorderSide.none,
      right: getSide('right') ?? BorderSide.none,
    );
  }
}
