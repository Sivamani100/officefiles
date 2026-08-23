import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../model/paragraph_model.dart';
import '../model/section_model.dart';
import '../model/run_model.dart';
import '../model/style_model.dart';
import '../model/table_model.dart';
import '../model/numbering_model.dart';
import '../utils/numbering_formatter.dart';
import '../utils/style_resolver.dart';
import '../utils/unit_converter.dart';
import '../renderer/header_footer_renderer.dart';
import '../renderer/paragraph_renderer.dart';
import '../renderer/list_renderer.dart';
import '../renderer/table_renderer.dart';
import 'pagination_engine.dart';

class PageRenderer extends StatelessWidget {
  final SectionModel section;
  final PageContent pageContent;
  final int pageIndex;
  final int totalPages;
  final Map<String, StyleModel> styles;
  final Map<String, NumberingDefinition> numbering;
  final Map<String, AbstractNumDefinition> abstractNumbering;
  /// Pre-computed numbering labels keyed by global block index.
  final Map<int, NumberingInfo> precomputedLabels;
  /// The global block index of the first block on this page.
  final int blockIndexOffset;
  final void Function(String? url, String? anchor)? onHyperlinkTap;

  const PageRenderer({
    super.key,
    required this.section,
    required this.pageContent,
    required this.pageIndex,
    required this.totalPages,
    required this.styles,
    required this.numbering,
    required this.abstractNumbering,
    required this.precomputedLabels,
    required this.blockIndexOffset,
    this.onHyperlinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final pageWidthPx = section.pageWidthDxa / 1440 * 96;
    final pageHeightPx = section.pageHeightDxa / 1440 * 96;
    
    final isEvenPage = pageIndex % 2 == 1;
    final double contentLeftPx;
    final double contentRightPx;
    if (section.mirrorMargins && isEvenPage) {
      contentLeftPx = section.marginRightDxa / 1440 * 96;
      contentRightPx = section.marginLeftDxa / 1440 * 96;
    } else {
      contentLeftPx = section.marginLeftDxa / 1440 * 96;
      contentRightPx = section.marginRightDxa / 1440 * 96;
    }

    final contentTopPx = section.marginTopDxa / 1440 * 96;
    final contentBottomPx = section.marginBottomDxa / 1440 * 96;
    final contentWidth = section.contentWidthPx;

    final contentWidgets = <Widget>[];
    dynamic previousBlock;

    final floatingImages = <Widget>[];
    for (final block in pageContent.blocks) {
      if (block is ParagraphModel) {
        for (final run in block.runs) {
          if (run.type == RunType.image && run.image != null && run.image!.wrapType != 'inline') {
            final img = run.image!;
            final imgWidthPx = UnitConverter.emuToPx(img.widthEmu);
            final imgHeightPx = UnitConverter.emuToPx(img.heightEmu);

            double xPx = 0.0;
            if (img.positionXEmu != null) {
              if (img.relativeFromH == 'page') {
                xPx = UnitConverter.emuToPx(img.positionXEmu!);
              } else {
                xPx = contentLeftPx + UnitConverter.emuToPx(img.positionXEmu!);
              }
            } else if (img.alignH != null) {
              final align = img.alignH!.toLowerCase();
              final rel = img.relativeFromH?.toLowerCase() ?? 'margin';
              if (rel == 'page') {
                if (align == 'center') {
                  xPx = (pageWidthPx - imgWidthPx) / 2;
                } else if (align == 'right') {
                  xPx = pageWidthPx - imgWidthPx;
                } else {
                  xPx = 0.0;
                }
              } else {
                if (align == 'center') {
                  xPx = contentLeftPx + (contentWidth - imgWidthPx) / 2;
                } else if (align == 'right') {
                  xPx = pageWidthPx - contentRightPx - imgWidthPx;
                } else {
                  xPx = contentLeftPx;
                }
              }
            } else {
              xPx = contentLeftPx + (contentWidth - imgWidthPx) / 2;
            }

            double yPx = 0.0;
            if (img.positionYEmu != null) {
              if (img.relativeFromV == 'page') {
                yPx = UnitConverter.emuToPx(img.positionYEmu!);
              } else {
                yPx = contentTopPx + UnitConverter.emuToPx(img.positionYEmu!);
              }
            } else if (img.alignV != null) {
              final align = img.alignV!.toLowerCase();
              final rel = img.relativeFromV?.toLowerCase() ?? 'margin';
              if (rel == 'page') {
                if (align == 'center') {
                  yPx = (pageHeightPx - imgHeightPx) / 2;
                } else if (align == 'bottom') {
                  yPx = pageHeightPx - imgHeightPx;
                } else {
                  yPx = 0.0;
                }
              } else {
                if (align == 'center') {
                  yPx = contentTopPx + (section.contentHeightPx - imgHeightPx) / 2;
                } else if (align == 'bottom') {
                  yPx = pageHeightPx - contentBottomPx - imgHeightPx;
                } else {
                  yPx = contentTopPx;
                }
              }
            } else {
              yPx = contentTopPx;
            }

            floatingImages.add(
              Positioned(
                left: xPx,
                top: yPx,
                child: Image.memory(
                  img.bytes,
                  width: imgWidthPx,
                  height: imgHeightPx,
                  fit: BoxFit.contain,
                ),
              ),
            );
          }
        }
      }
    }

    for (int i = 0; i < pageContent.blocks.length; i++) {
      final block = pageContent.blocks[i];
      final globalIndex = blockIndexOffset + i;

      if (block is ParagraphModel) {
        // Spacing collapse between blocks
        if (previousBlock != null) {
          final gap = _resolveSpacingBetween(previousBlock, block);
          if (gap > 0) {
            contentWidgets.add(SizedBox(height: gap));
          }
        }
        contentWidgets.add(_buildBlockWidget(block, contentWidth, globalIndex));
        previousBlock = block;
      } else if (block is TableModel) {
        // Spacing before table
        if (previousBlock != null) {
          final gap = _resolveSpacingBetween(previousBlock, block);
          if (gap > 0) {
            contentWidgets.add(SizedBox(height: gap));
          }
        }
        contentWidgets.add(
          TableRenderer(
            table: block,
            styles: styles,
            contentWidth: contentWidth,
            pageIndex: pageIndex,
            totalPages: totalPages,
            onHyperlinkTap: onHyperlinkTap,
          ),
        );
        previousBlock = block;
      } else {
        // Unknown block type
        if (previousBlock != null) {
          final gap = _resolveSpacingBetween(previousBlock, null);
          if (gap > 0) {
            contentWidgets.add(SizedBox(height: gap));
          }
        }
        contentWidgets.add(const SizedBox.shrink());
        previousBlock = null;
      }
    }

    // Determine header for this page
    final headerModel = _resolveHeader();
    // Determine footer for this page
    final footerModel = _resolveFooter();

    // Calculate effective margins
    double effectiveTopPx = contentTopPx;
    if (headerModel != null) {
      double headerHeight = 0.0;
      for (final block in headerModel.blocks) {
        headerHeight += PaginationEngine.estimateBlockHeight(
          block,
          contentWidth,
          styles,
          numbering,
          abstractNumbering,
        );
      }
      final headerDistancePx = section.headerDistanceDxa / 1440 * 96;
      effectiveTopPx = math.max(contentTopPx, headerDistancePx + headerHeight);
    }

    double effectiveBottomPx = contentBottomPx;
    if (footerModel != null) {
      double footerHeight = 0.0;
      for (final block in footerModel.blocks) {
        footerHeight += PaginationEngine.estimateBlockHeight(
          block,
          contentWidth,
          styles,
          numbering,
          abstractNumbering,
        );
      }
      final footerDistancePx = section.footerDistanceDxa / 1440 * 96;
      effectiveBottomPx = math.max(contentBottomPx, footerDistancePx + footerHeight);
    }

    return Container(
      width: pageWidthPx,
      height: pageHeightPx,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          _buildCornerMarker(Alignment.topLeft),
          _buildCornerMarker(Alignment.topRight),
          _buildCornerMarker(Alignment.bottomLeft),
          _buildCornerMarker(Alignment.bottomRight),
          // Content area with ClipRect to prevent overflow
          Positioned(
            top: effectiveTopPx,
            left: contentLeftPx,
            right: contentRightPx,
            bottom: effectiveBottomPx,
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: contentWidgets,
              ),
            ),
          ),
          ...floatingImages,
          // Header
          if (headerModel != null)
            Positioned(
              top: section.headerDistanceDxa / 1440 * 96,
              left: contentLeftPx,
              right: contentRightPx,
              child: HeaderFooterRenderer(
                model: headerModel,
                contentWidth: contentWidth,
                styles: styles,
              ),
            ),
          // Footer
          if (footerModel != null)
            Positioned(
              bottom: section.footerDistanceDxa / 1440 * 96,
              left: contentLeftPx,
              right: contentRightPx,
              child: HeaderFooterRenderer(
                model: footerModel,
                contentWidth: contentWidth,
                styles: styles,
              ),
            ),
        ],
      ),
    );
  }

  /// Resolve which header to use based on page index and section settings.
  dynamic _resolveHeader() {
    if (pageIndex == 0 && section.differentFirstPage && section.firstPageHeader != null) {
      return section.firstPageHeader;
    }
    if (section.differentOddEven) {
      final isEvenPage = pageIndex % 2 == 1;
      if (isEvenPage) {
        return section.evenHeader ?? section.defaultHeader;
      } else {
        return section.oddHeader ?? section.defaultHeader;
      }
    }
    return section.defaultHeader;
  }

  /// Resolve which footer to use based on page index and section settings.
  dynamic _resolveFooter() {
    if (pageIndex == 0 && section.differentFirstPage && section.firstPageFooter != null) {
      return section.firstPageFooter;
    }
    if (section.differentOddEven) {
      final isEvenPage = pageIndex % 2 == 1;
      if (isEvenPage) {
        return section.evenFooter ?? section.defaultFooter;
      } else {
        return section.oddFooter ?? section.defaultFooter;
      }
    }
    return section.defaultFooter;
  }

  Widget _buildBlockWidget(ParagraphModel paragraph, double contentWidth, int globalIndex) {
    final info = precomputedLabels[globalIndex];
    if (info != null) {
      return ListRenderer(
        paragraph: paragraph,
        labelText: info.label,
        contentWidth: contentWidth,
        styles: styles,
        levelIndentDxa: info.level.indent,
        levelHangingDxa: info.level.hanging,
        levelRPr: info.level.rPr,
        pageIndex: pageIndex,
        totalPages: totalPages,
        onHyperlinkTap: onHyperlinkTap,
      );
    }
    return ParagraphRenderer(
      paragraph: paragraph,
      styles: styles,
      contentWidth: contentWidth,
      pageIndex: pageIndex,
      totalPages: totalPages,
      onHyperlinkTap: onHyperlinkTap,
    );
  }

  /// Resolve spacing between two adjacent blocks with proper collapse rules.
  double _resolveSpacingBetween(dynamic above, dynamic below) {
    if (above is ParagraphModel && below is ParagraphModel) {
      final styleAbove = StyleResolver.resolveParagraph(above, styles);
      final styleBelow = StyleResolver.resolveParagraph(below, styles);

      final afterPx = styleAbove.spacingAfterDxa / 1440 * 96;
      final beforePx = styleBelow.spacingBeforeDxa / 1440 * 96;

      final numAbove = StyleResolver.resolveNumbering(above, styles);
      final numBelow = StyleResolver.resolveNumbering(below, styles);
      if (numAbove != null && numBelow != null && numAbove.numId == numBelow.numId) {
        return 0.0;
      }

      if (above.styleId != null &&
          above.styleId == below.styleId &&
          (styleAbove.contextualSpacing || styleBelow.contextualSpacing)) {
        return 0.0;
      }

      return afterPx > beforePx ? afterPx : beforePx;
    }

    if (above is ParagraphModel && below is TableModel) {
      final styleAbove = StyleResolver.resolveParagraph(above, styles);
      return styleAbove.spacingAfterDxa / 1440 * 96;
    }

    if (above is TableModel && below is ParagraphModel) {
      final styleBelow = StyleResolver.resolveParagraph(below, styles);
      return styleBelow.spacingBeforeDxa / 1440 * 96;
    }

    if (above is TableModel && below is TableModel) {
      return 8.0;
    }

    if (above is ParagraphModel && below == null) {
      final styleAbove = StyleResolver.resolveParagraph(above, styles);
      return styleAbove.spacingAfterDxa / 1440 * 96;
    }

    return 0.0;
  }

  Widget _buildCornerMarker(Alignment alignment) {
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: SizedBox(
        width: 16,
        height: 16,
        child: CustomPaint(
          painter: _CornerMarkerPainter(isLeft: isLeft, isTop: isTop, color: const Color(0xFFBBBBBB)),
        ),
      ),
    );
  }
}

class _CornerMarkerPainter extends CustomPainter {
  final bool isLeft;
  final bool isTop;
  final Color color;

  _CornerMarkerPainter({required this.isLeft, required this.isTop, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final y = isTop ? 2.0 : size.height - 2.0;
    final x = isLeft ? 2.0 : size.width - 2.0;

    canvas.drawLine(Offset(isLeft ? 2.0 : 0.0, y), Offset(isLeft ? size.width : size.width - 2.0, y), paint);
    canvas.drawLine(Offset(x, isTop ? 2.0 : 0.0), Offset(x, isTop ? size.height : size.height - 2.0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
