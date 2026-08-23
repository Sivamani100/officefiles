import 'package:flutter/material.dart';

import 'run_model.dart';
import 'numbering_model.dart';
import 'style_model.dart';

enum ParagraphAlignment { left, center, right, both, distribute, unknown }

class ParagraphModel {
  final String? styleId;
  final ParagraphAlignment? alignment;
  final int? spacingBeforeDxa;
  final int? spacingAfterDxa;
  final int? lineSpacingValue;
  final LineSpacingRule? lineSpacingRule;
  final int? indentLeftDxa;
  final int? indentRightDxa;
  final int? indentFirstLineDxa;
  final int? indentHangingDxa;
  final bool? keepWithNext;
  final bool? keepLines;
  final bool? pageBreakBefore;
  final bool? contextualSpacing;
  final int? outlineLevel;
  final NumberingReference? numbering;
  final Map<String, dynamic>? borders;
  final Color? shading;
  final List<dynamic> customTabStops;
  final Map<String, dynamic>? defaultRunProperties;
  final List<RunModel> runs;
  final bool? bidi;

  ParagraphModel({
    this.styleId,
    this.alignment,
    this.spacingBeforeDxa,
    this.spacingAfterDxa,
    this.lineSpacingValue,
    this.lineSpacingRule,
    this.indentLeftDxa,
    this.indentRightDxa,
    this.indentFirstLineDxa,
    this.indentHangingDxa,
    this.keepWithNext,
    this.keepLines,
    this.pageBreakBefore,
    this.contextualSpacing,
    this.outlineLevel,
    this.numbering,
    this.borders,
    this.shading,
    List<dynamic>? customTabStops,
    this.defaultRunProperties,
    List<RunModel>? runs,
    this.bidi,
  })  : customTabStops = customTabStops ?? [],
        runs = runs ?? [];

  /// Creates a shallow copy with selectively overridden fields.
  ParagraphModel copyWith({
    String? Function()? styleId,
    ParagraphAlignment? Function()? alignment,
    int? Function()? spacingBeforeDxa,
    int? Function()? spacingAfterDxa,
    int? Function()? lineSpacingValue,
    LineSpacingRule? Function()? lineSpacingRule,
    int? Function()? indentLeftDxa,
    int? Function()? indentRightDxa,
    int? Function()? indentFirstLineDxa,
    int? Function()? indentHangingDxa,
    bool? Function()? keepWithNext,
    bool? Function()? keepLines,
    bool? Function()? pageBreakBefore,
    bool? Function()? contextualSpacing,
    int? Function()? outlineLevel,
    NumberingReference? Function()? numbering,
    Map<String, dynamic>? Function()? borders,
    Color? Function()? shading,
    List<dynamic>? customTabStopsOverride,
    Map<String, dynamic>? Function()? defaultRunProperties,
    List<RunModel>? runsOverride,
    bool? Function()? bidi,
  }) {
    return ParagraphModel(
      styleId: styleId != null ? styleId() : this.styleId,
      alignment: alignment != null ? alignment() : this.alignment,
      spacingBeforeDxa: spacingBeforeDxa != null ? spacingBeforeDxa() : this.spacingBeforeDxa,
      spacingAfterDxa: spacingAfterDxa != null ? spacingAfterDxa() : this.spacingAfterDxa,
      lineSpacingValue: lineSpacingValue != null ? lineSpacingValue() : this.lineSpacingValue,
      lineSpacingRule: lineSpacingRule != null ? lineSpacingRule() : this.lineSpacingRule,
      indentLeftDxa: indentLeftDxa != null ? indentLeftDxa() : this.indentLeftDxa,
      indentRightDxa: indentRightDxa != null ? indentRightDxa() : this.indentRightDxa,
      indentFirstLineDxa: indentFirstLineDxa != null ? indentFirstLineDxa() : this.indentFirstLineDxa,
      indentHangingDxa: indentHangingDxa != null ? indentHangingDxa() : this.indentHangingDxa,
      keepWithNext: keepWithNext != null ? keepWithNext() : this.keepWithNext,
      keepLines: keepLines != null ? keepLines() : this.keepLines,
      pageBreakBefore: pageBreakBefore != null ? pageBreakBefore() : this.pageBreakBefore,
      contextualSpacing: contextualSpacing != null ? contextualSpacing() : this.contextualSpacing,
      outlineLevel: outlineLevel != null ? outlineLevel() : this.outlineLevel,
      numbering: numbering != null ? numbering() : this.numbering,
      borders: borders != null ? borders() : this.borders,
      shading: shading != null ? shading() : this.shading,
      customTabStops: customTabStopsOverride ?? this.customTabStops,
      defaultRunProperties: defaultRunProperties != null ? defaultRunProperties() : this.defaultRunProperties,
      runs: runsOverride ?? this.runs,
      bidi: bidi != null ? bidi() : this.bidi,
    );
  }
}
