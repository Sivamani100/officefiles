import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../model/header_footer_model.dart';
import '../model/paragraph_model.dart';
import '../model/run_model.dart';
import '../model/section_model.dart';
import '../model/table_model.dart';
import '../model/style_model.dart';
import '../model/numbering_model.dart';
import '../utils/style_resolver.dart';
import '../utils/unit_converter.dart';
import 'run_renderer.dart';

class PageContent {
  final List<dynamic> blocks;
  PageContent({required this.blocks});
}

class PaginationEngine {
  static HeaderFooterModel? _resolveHeader(SectionModel section, int pageIndex) {
    if (pageIndex == 0 && section.differentFirstPage && section.firstPageHeader != null) {
      return section.firstPageHeader;
    }
    if (section.differentOddEven) {
      final isEvenPage = pageIndex % 2 == 1; // 0-based pageIndex 1 is Page 2 (even)
      if (isEvenPage) {
        return section.evenHeader ?? section.defaultHeader;
      } else {
        return section.oddHeader ?? section.defaultHeader;
      }
    }
    return section.defaultHeader;
  }

  static HeaderFooterModel? _resolveFooter(SectionModel section, int pageIndex) {
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

  static List<PageContent> paginate(
    SectionModel section,
    Map<String, StyleModel> styles, [
    Map<String, NumberingDefinition>? numbering,
    Map<String, AbstractNumDefinition>? abstractNumbering,
  ]) {
    final contentWidthPx = section.contentWidthPx;
    final contentTopPx = section.marginTopPx;
    final contentBottomPx = section.marginBottomPx;
    final pageHeightPx = section.pageHeightPx;

    double getEffectiveContentHeight(int pageIndex) {
      final headerModel = _resolveHeader(section, pageIndex);
      final footerModel = _resolveFooter(section, pageIndex);

      double effectiveTopPx = contentTopPx;
      if (headerModel != null) {
        double headerHeight = 0.0;
        for (final block in headerModel.blocks) {
          headerHeight += estimateBlockHeight(block, contentWidthPx, styles, numbering, abstractNumbering);
        }
        final headerDistancePx = section.headerDistanceDxa / 1440 * 96;
        effectiveTopPx = math.max(contentTopPx, headerDistancePx + headerHeight);
      }

      double effectiveBottomPx = contentBottomPx;
      if (footerModel != null) {
        double footerHeight = 0.0;
        for (final block in footerModel.blocks) {
          footerHeight += estimateBlockHeight(block, contentWidthPx, styles, numbering, abstractNumbering);
        }
        final footerDistancePx = section.footerDistanceDxa / 1440 * 96;
        effectiveBottomPx = math.max(contentBottomPx, footerDistancePx + footerHeight);
      }

      return pageHeightPx - effectiveTopPx - effectiveBottomPx;
    }

    var currentY = 0.0;
    var currentBlocks = <dynamic>[];
    final pages = <PageContent>[];

    final blocks = section.blocks;

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      // Spacing gap between previous block and current block
      double gap = 0.0;
      if (currentBlocks.isNotEmpty) {
        gap = _resolveSpacingBetween(currentBlocks.last, block, styles);
      }

      // --- Page break handling for paragraphs ---
      if (block is ParagraphModel) {
        final blockStyle = StyleResolver.resolveParagraph(block, styles);
        // Check pageBreakBefore
        if (blockStyle.pageBreakBefore && currentBlocks.isNotEmpty) {
          pages.add(PageContent(blocks: List.of(currentBlocks)));
          currentBlocks = <dynamic>[];
          currentY = 0.0;
          gap = 0.0; // Reset gap since it's now the first block on a new page
        }

        // Check for runs with RunType.pageBreak
        bool hasPageBreakRun = false;
        for (final run in block.runs) {
          if (run.type == RunType.pageBreak) {
            hasPageBreakRun = true;
            break;
          }
        }
        if (hasPageBreakRun && currentBlocks.isNotEmpty) {
          pages.add(PageContent(blocks: List.of(currentBlocks)));
          currentBlocks = <dynamic>[];
          currentY = 0.0;
          gap = 0.0; // Reset gap
        }
      }

      // --- Estimate block height ---
      final blockHeight = estimateBlockHeight(block, contentWidthPx, styles, numbering, abstractNumbering);

      final currentHeightLimit = getEffectiveContentHeight(pages.length);

      // --- Page overflow check ---
      if (currentY + gap + blockHeight > currentHeightLimit && currentBlocks.isNotEmpty) {
        // Find if we can backtrack due to keepWithNext chains.
        int breakIndex = currentBlocks.length; // default to break before the current block

        for (int j = currentBlocks.length - 1; j > 0; j--) {
          final prevBlock = currentBlocks[j - 1];
          if (prevBlock is ParagraphModel) {
            final prevStyle = StyleResolver.resolveParagraph(prevBlock, styles);
            if (!prevStyle.keepWithNext) {
              breakIndex = j;
              break;
            }
          } else {
            // Non-paragraph blocks (like tables) do not have keepWithNext; we can break before them.
            breakIndex = j;
            break;
          }
        }

        if (breakIndex < currentBlocks.length) {
          // We found a keepWithNext boundary!
          // Split the blocks.
          final pageBlocks = currentBlocks.sublist(0, breakIndex);
          final carriedBlocks = currentBlocks.sublist(breakIndex);

          pages.add(PageContent(blocks: pageBlocks));

          // Re-initialize currentBlocks with carried blocks
          currentBlocks = carriedBlocks;

          // Re-calculate currentY for the new page
          currentY = 0.0;
          for (int c = 0; c < currentBlocks.length; c++) {
            final carried = currentBlocks[c];
            double carriedGap = 0.0;
            if (c > 0) {
              carriedGap = _resolveSpacingBetween(currentBlocks[c - 1], carried, styles);
            }
            final carriedHeight = estimateBlockHeight(carried, contentWidthPx, styles, numbering, abstractNumbering);
            currentY += carriedGap + carriedHeight;
          }

          // Now, re-evaluate gap for the current block on the new page
          gap = _resolveSpacingBetween(currentBlocks.last, block, styles);
        } else {
          // No backtrack boundary found (the entire page is one keepWithNext chain).
          // Break before the current block (default behavior).
          pages.add(PageContent(blocks: List.of(currentBlocks)));
          currentBlocks = <dynamic>[];
          currentY = 0.0;
          gap = 0.0; // Reset gap
        }
      }

      currentBlocks.add(block);
      currentY += gap + blockHeight;
    }

    // Final page
    if (currentBlocks.isNotEmpty) {
      pages.add(PageContent(blocks: currentBlocks));
    }

    // Ensure at least one page
    if (pages.isEmpty) {
      pages.add(PageContent(blocks: []));
    }

    return pages;
  }

  /// Estimate the pixel height of a block for pagination purposes.
  static double estimateBlockHeight(
    dynamic block,
    double contentWidthPx,
    Map<String, StyleModel> styles, [
    Map<String, NumberingDefinition>? numbering,
    Map<String, AbstractNumDefinition>? abstractNumbering,
  ]) {
    if (block is ParagraphModel) {
      return _estimateParagraphHeight(block, contentWidthPx, styles, numbering, abstractNumbering);
    }
    if (block is TableModel) {
      return _estimateTableHeight(block, styles, numbering, abstractNumbering);
    }
    // Unknown block type — use a default
    return 24.0;
  }

  static double _estimateParagraphHeight(
    ParagraphModel paragraph,
    double contentWidthPx,
    Map<String, StyleModel> styles,
    Map<String, NumberingDefinition>? numbering,
    Map<String, AbstractNumDefinition>? abstractNumbering,
  ) {
    final blockStyle = StyleResolver.resolveParagraph(paragraph, styles);

    // 1. Calculate left/right indents and text width
    double leftPadding = 0.0;
    double labelWidth = 0.0;
    double rightPadding = blockStyle.indentRightDxa > 0 
        ? UnitConverter.dxaToPx(blockStyle.indentRightDxa) 
        : 0.0;

    final resolvedNumRef = StyleResolver.resolveNumbering(paragraph, styles);
    if (resolvedNumRef != null) {
      final numRef = resolvedNumRef;
      final definition = numbering?[numRef.numId];
      final double totalIndentPx;
      final double hangingPx;
      if (definition != null && abstractNumbering != null) {
        final abstractNum = abstractNumbering[definition.abstractNumId];
        final level = abstractNum?.levels[numRef.ilvl];
        final indentDxa = level?.indent ?? blockStyle.indentLeftDxa;
        totalIndentPx = UnitConverter.dxaToPx(indentDxa > 0 ? indentDxa : 720);
        hangingPx = level?.hanging != null 
            ? UnitConverter.dxaToPx(level!.hanging!) 
            : 32.0;
      } else {
        totalIndentPx = UnitConverter.dxaToPx(blockStyle.indentLeftDxa > 0 ? blockStyle.indentLeftDxa : 720);
        hangingPx = blockStyle.indentHangingDxa > 0 
            ? UnitConverter.dxaToPx(blockStyle.indentHangingDxa) 
            : 32.0;
      }
      final double actualLabelWidth = hangingPx < 36.0 ? 36.0 : hangingPx;
      leftPadding = (totalIndentPx - actualLabelWidth).clamp(0.0, double.infinity);
      labelWidth = actualLabelWidth;
    } else {
      leftPadding = blockStyle.indentLeftDxa > 0 
          ? UnitConverter.dxaToPx(blockStyle.indentLeftDxa) 
          : 0.0;
    }

    final double textWidthPx = (contentWidthPx - leftPadding - labelWidth - rightPadding).clamp(1.0, double.infinity);

    // 2. Build the runs list (exactly as in ParagraphRenderer)
    final children = <InlineSpan>[];
    for (int runIdx = 0; runIdx < paragraph.runs.length; runIdx++) {
      final run = paragraph.runs[runIdx];
      final effective = StyleResolver.resolve(paragraph, run, styles);
      children.add(RunRenderer.buildRunSpan(
        run,
        effective,
        blockStyle,
        paragraph.runs,
        runIdx,
        0,
        1,
        paragraph.customTabStops,
        null,
      ));
    }

    // First line indent support
    if (blockStyle.indentFirstLineDxa > 0) {
      final firstLineIndentPx = UnitConverter.dxaToPx(blockStyle.indentFirstLineDxa);
      children.insert(0, WidgetSpan(child: SizedBox(width: firstLineIndentPx)));
    }

    // 3. Layout with TextPainter
    final textSpan = TextSpan(children: children);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    );
    textPainter.layout(maxWidth: textWidthPx);
    double paragraphHeight = textPainter.height;

    // If the paragraph has no visible height (e.g. empty line), give it a fallback height
    // based on default font size so it consumes page space.
    if (paragraphHeight == 0.0) {
      double fontSizePt = 11.0;
      if (paragraph.defaultRunProperties != null) {
        final drpSize = paragraph.defaultRunProperties!['fontSize'];
        if (drpSize is int && drpSize > 0) {
          fontSizePt = drpSize / 2.0;
        }
      }
      paragraphHeight = (fontSizePt * 96.0 / 72.0) * 1.2;
    }

    // Account for paragraph padding/borders if present
    if (blockStyle.shading != null || blockStyle.borders != null) {
      paragraphHeight += 8.0; // top + bottom padding of 4px each
    }

    // Apply a scaling factor and safety padding to account for font rendering metrics variations
    // (such as asynchronously loaded Google Fonts) to prevent page overflow and clipping.
    return paragraphHeight * 1.08 + 2.0;
  }

  static double _estimateTableHeight(
    TableModel table,
    Map<String, StyleModel> styles,
    Map<String, NumberingDefinition>? numbering,
    Map<String, AbstractNumDefinition>? abstractNumbering,
  ) {
    double totalHeight = 0.0;
    for (final row in table.rows) {
      totalHeight += _estimateTableRowHeight(row, table.columnWidthsDxa, styles, numbering, abstractNumbering);
    }
    return totalHeight > 0 ? totalHeight : 48.0;
  }

  static double _estimateTableRowHeight(
    TableRowModel row,
    List<int> columnWidthsDxa,
    Map<String, StyleModel> styles,
    Map<String, NumberingDefinition>? numbering,
    Map<String, AbstractNumDefinition>? abstractNumbering,
  ) {
    if (row.heightDxa != null && row.heightDxa! > 0 && row.heightRule == HeightRule.exact) {
      return row.heightDxa! / 1440.0 * 96.0;
    }

    double maxCellHeight = 0.0;
    for (int colIdx = 0; colIdx < row.cells.length; colIdx++) {
      final cell = row.cells[colIdx];
      
      // Determine cell width based on grid columns and grid span
      double cellWidthDxa = 0.0;
      final span = cell.gridSpan;
      for (int s = 0; s < span; s++) {
        final idx = colIdx + s;
        if (idx < columnWidthsDxa.length) {
          cellWidthDxa += columnWidthsDxa[idx];
        }
      }
      
      if (cellWidthDxa == 0.0) {
        cellWidthDxa = cell.widthDxa > 0 ? cell.widthDxa.toDouble() : 1440.0;
      }
      
      final cellWidthPx = cellWidthDxa / 1440.0 * 96.0;
      
      double cellHeight = 0.0;
      for (final p in cell.paragraphs) {
        cellHeight += _estimateParagraphHeight(p, cellWidthPx, styles, numbering, abstractNumbering);
      }
      
      // Cell margins
      double cellPaddingPx = 12.0; // fallback vertical padding (6px top, 6px bottom)
      if (cell.margins != null) {
        final top = cell.margins!['top'] ?? 0;
        final bottom = cell.margins!['bottom'] ?? 0;
        if (top > 0 || bottom > 0) {
          cellPaddingPx = (top + bottom) / 1440.0 * 96.0;
        }
      }
      
      cellHeight += cellPaddingPx;
      
      if (cellHeight > maxCellHeight) {
        maxCellHeight = cellHeight;
      }
    }

    final minHeight = (row.heightDxa != null && row.heightDxa! > 0)
        ? row.heightDxa! / 1440.0 * 96.0
        : 24.0; // default row height

    return maxCellHeight > minHeight ? maxCellHeight : minHeight;
  }

  /// Resolve spacing between two adjacent blocks with proper collapse rules.
  static double _resolveSpacingBetween(dynamic above, dynamic below, Map<String, StyleModel> styles) {
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

    return 0.0;
  }
}
