import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../model/style_model.dart';
import '../model/table_model.dart';
import '../utils/color_resolver.dart';
import '../utils/unit_converter.dart';
import 'paragraph_renderer.dart';

class TableRenderer extends StatelessWidget {
  final TableModel table;
  final Map<String, StyleModel> styles;
  final double? contentWidth;
  final int pageIndex;
  final int totalPages;
  final void Function(String? url, String? anchor)? onHyperlinkTap;

  const TableRenderer({
    super.key,
    required this.table,
    required this.styles,
    this.contentWidth,
    this.pageIndex = 0,
    this.totalPages = 1,
    this.onHyperlinkTap,
  });

  @override
  Widget build(BuildContext context) {
    if (table.rows.isEmpty) return const SizedBox.shrink();

    // Sum column widths to get table width in pixels
    final double tableWidthPx = table.columnWidthsDxa.isNotEmpty
        ? table.columnWidthsDxa.fold(0.0, (sum, w) => sum + UnitConverter.dxaToPx(w))
        : (contentWidth ?? 500.0);

    // Determine alignment of the table itself on the page
    CrossAxisAlignment rowAlignment = CrossAxisAlignment.start;
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start;
    if (table.alignment == TableAlignment.center) {
      mainAxisAlignment = MainAxisAlignment.center;
    } else if (table.alignment == TableAlignment.right) {
      mainAxisAlignment = MainAxisAlignment.end;
    }

    // Build grid cells map to analyze vertical merges across rows
    final int totalCols = table.columnWidthsDxa.isNotEmpty
        ? table.columnWidthsDxa.length
        : table.rows.fold(0, (max, r) => math.max(max, r.cells.fold(0, (sum, c) => sum + c.gridSpan)));

    final List<List<TableCellModel?>> grid = List.generate(
      table.rows.length,
      (_) => List.filled(totalCols, null),
    );

    for (int r = 0; r < table.rows.length; r++) {
      int colIdx = 0;
      for (int c = 0; c < table.rows[r].cells.length; c++) {
        final cell = table.rows[r].cells[c];
        for (int s = 0; s < cell.gridSpan; s++) {
          if (colIdx < totalCols) {
            grid[r][colIdx] = cell;
          }
        }
        colIdx += cell.gridSpan;
      }
    }

    final List<Widget> rowWidgets = [];

    for (int r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      final List<Widget> cellWidgets = [];

      // Tracks the column index in the grid
      int gridColIdx = 0;

      for (int c = 0; c < row.cells.length; c++) {
        final cell = row.cells[c];
        final span = cell.gridSpan;

        // Calculate cell width in pixels based on spanned columns in tblGrid
        double cellWidthPx = 0.0;
        for (int s = 0; s < span; s++) {
          final colIdx = gridColIdx + s;
          if (colIdx < table.columnWidthsDxa.length) {
            cellWidthPx += UnitConverter.dxaToPx(table.columnWidthsDxa[colIdx]);
          } else {
            // Fallback column width
            cellWidthPx += tableWidthPx / (table.columnWidthsDxa.isNotEmpty ? table.columnWidthsDxa.length : 1);
          }
        }

        // Resolve cell margins (padding)
        double topMar = 4.0;
        double bottomMar = 4.0;
        double leftMar = 6.0;
        double rightMar = 6.0;

        if (cell.margins != null) {
          topMar = UnitConverter.dxaToPx(cell.margins!['top'] ?? 80).clamp(0.0, 50.0);
          bottomMar = UnitConverter.dxaToPx(cell.margins!['bottom'] ?? 80).clamp(0.0, 50.0);
          leftMar = UnitConverter.dxaToPx(cell.margins!['left'] ?? cell.margins!['start'] ?? 108).clamp(0.0, 50.0);
          rightMar = UnitConverter.dxaToPx(cell.margins!['right'] ?? cell.margins!['end'] ?? 108).clamp(0.0, 50.0);
        } else if (table.defaultCellMargins != null) {
          topMar = UnitConverter.dxaToPx(table.defaultCellMargins!['top'] ?? 80).clamp(0.0, 50.0);
          bottomMar = UnitConverter.dxaToPx(table.defaultCellMargins!['bottom'] ?? 80).clamp(0.0, 50.0);
          leftMar = UnitConverter.dxaToPx(table.defaultCellMargins!['left'] ?? table.defaultCellMargins!['start'] ?? 108).clamp(0.0, 50.0);
          rightMar = UnitConverter.dxaToPx(table.defaultCellMargins!['right'] ?? table.defaultCellMargins!['end'] ?? 108).clamp(0.0, 50.0);
        }

        // Shading background color
        Color? shadingColor = cell.shading;
        final bool isContinueMerge = cell.vMerge == VerticalMergeType.continueMerge;

        if (isContinueMerge) {
          // Find the restart cell's shading
          for (int prevR = r - 1; prevR >= 0; prevR--) {
            final prevCell = grid[prevR][gridColIdx];
            if (prevCell != null) {
              if (prevCell.vMerge == VerticalMergeType.restart) {
                shadingColor = prevCell.shading;
                break;
              } else if (prevCell.vMerge == null) {
                break;
              }
            }
          }
        }

        // Resolve borders for this cell (check cell-level first, then table-level)
        final bool hasContinueBelow = (r + 1 < table.rows.length) &&
            (grid[r + 1][gridColIdx]?.vMerge == VerticalMergeType.continueMerge);

        BorderSide topSide = _resolveBorderSide(cell.borders ?? table.borders, 'top');
        BorderSide bottomSide = _resolveBorderSide(cell.borders ?? table.borders, 'bottom');
        BorderSide leftSide = _resolveBorderSide(cell.borders ?? table.borders, 'left');
        BorderSide rightSide = _resolveBorderSide(cell.borders ?? table.borders, 'right');

        if (isContinueMerge) {
          topSide = BorderSide.none;
        }
        if (hasContinueBelow) {
          bottomSide = BorderSide.none;
        }

        final cellBorder = Border(
          top: topSide,
          bottom: bottomSide,
          left: leftSide,
          right: rightSide,
        );

        // Vertical Alignment inside the cell
        Alignment cellAlign = Alignment.centerLeft;
        if (cell.verticalAlignment == VerticalAlignment.subscript) {
          cellAlign = Alignment.bottomLeft;
        } else if (cell.verticalAlignment == VerticalAlignment.superscript) {
          cellAlign = Alignment.topLeft;
        }

        final List<Widget> children = [];
        if (!isContinueMerge) {
          children.addAll(cell.paragraphs.map((para) {
            return ParagraphRenderer(
              paragraph: para,
              styles: styles,
              contentWidth: cellWidthPx - leftMar - rightMar,
              pageIndex: pageIndex,
              totalPages: totalPages,
              onHyperlinkTap: onHyperlinkTap,
            );
          }));
        }

        Widget cellContent = Container(
          width: cellWidthPx,
          padding: EdgeInsets.only(
            top: topMar,
            bottom: bottomMar,
            left: leftMar,
            right: rightMar,
          ),
          decoration: BoxDecoration(
            color: shadingColor,
            border: cellBorder,
          ),
          alignment: cellAlign,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );

        cellWidgets.add(cellContent);
        gridColIdx += span;
      }

      rowWidgets.add(
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cellWidgets,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: rowAlignment,
      mainAxisSize: MainAxisSize.min,
      children: rowWidgets,
    );
  }

  BorderSide _resolveBorderSide(Map<String, dynamic>? borderMap, String side) {
    if (borderMap == null || !borderMap.containsKey(side)) {
      return const BorderSide(color: Colors.black12, width: 0.5); // thin default border
    }
    final info = borderMap[side];
    if (info == null) return const BorderSide(color: Colors.black12, width: 0.5);
    
    final String val = info['val'] ?? 'none';
    if (val == 'none' || val == 'nil') {
      return BorderSide.none;
    }
    
    final int sz = info['sz'] ?? 4;
    final double width = (sz / 8.0 * 96.0 / 72.0).clamp(0.5, 10.0);
    final String colorHex = info['color'] ?? 'auto';
    final Color color = colorHex == 'auto'
        ? Colors.black26
        : ColorResolver.resolve(hexValue: colorHex, theme: null);

    return BorderSide(color: color, width: width);
  }
}
