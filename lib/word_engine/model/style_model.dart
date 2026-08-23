enum StyleType { paragraph, character, table }

enum UnderlineType { none, single, double, dotted, dashed, wave }

enum LineSpacingRule { auto, exact, atLeast }

enum VerticalAlignment { baseline, superscript, subscript }

class StyleModel {
  final String styleId;
  final String? name;
  final StyleType type;
  final String? basedOn;
  final String? linkedStyle;
  final Map<String, dynamic> paragraphProperties;
  final Map<String, dynamic> runProperties;

  StyleModel({
    required this.styleId,
    this.name,
    required this.type,
    this.basedOn,
    this.linkedStyle,
    Map<String, dynamic>? paragraphProperties,
    Map<String, dynamic>? runProperties,
  })  : paragraphProperties = paragraphProperties ?? {},
        runProperties = runProperties ?? {};
}
