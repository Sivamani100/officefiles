import 'package:flutter/material.dart';

import 'paragraph_model.dart';
import 'style_model.dart';

enum TableAlignment { left, center, right }

enum HeightRule { auto, exact, atLeast }

enum VerticalMergeType { restart, continueMerge }

class TableCellModel {
  final int widthDxa;
  final int gridSpan;
  final VerticalMergeType? vMerge;
  final Map<String, dynamic>? borders;
  final Color? shading;
  final VerticalAlignment verticalAlignment;
  final Map<String, int>? margins;
  final List<ParagraphModel> paragraphs;

  TableCellModel({
    this.widthDxa = 0,
    this.gridSpan = 1,
    this.vMerge,
    this.borders,
    this.shading,
    this.verticalAlignment = VerticalAlignment.baseline,
    this.margins,
    List<ParagraphModel>? paragraphs,
  }) : paragraphs = paragraphs ?? [];
}

class TableRowModel {
  final int? heightDxa;
  final HeightRule heightRule;
  final bool isHeader;
  final bool cantSplit;
  final List<TableCellModel> cells;

  TableRowModel({
    this.heightDxa,
    this.heightRule = HeightRule.auto,
    this.isHeader = false,
    this.cantSplit = false,
    List<TableCellModel>? cells,
  }) : cells = cells ?? [];
}

class TableModel {
  final int totalWidthDxa;
  final TableAlignment alignment;
  final List<int> columnWidthsDxa;
  final Map<String, dynamic>? borders;
  final Map<String, int>? defaultCellMargins;
  final List<TableRowModel> rows;

  TableModel({
    this.totalWidthDxa = 0,
    this.alignment = TableAlignment.left,
    List<int>? columnWidthsDxa,
    this.borders,
    this.defaultCellMargins,
    List<TableRowModel>? rows,
  })  : columnWidthsDxa = columnWidthsDxa ?? [],
        rows = rows ?? [];
}
