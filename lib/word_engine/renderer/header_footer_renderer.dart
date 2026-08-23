import 'package:flutter/material.dart';

import '../model/header_footer_model.dart';
import '../model/paragraph_model.dart';
import '../model/table_model.dart';
import '../model/style_model.dart';
import 'paragraph_renderer.dart';
import 'table_renderer.dart';

class HeaderFooterRenderer extends StatelessWidget {
  final HeaderFooterModel model;
  final double? contentWidth;
  final Map<String, StyleModel> styles;

  const HeaderFooterRenderer({
    super.key,
    required this.model,
    this.contentWidth,
    required this.styles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: model.blocks.map((block) {
        if (block is ParagraphModel) {
          return ParagraphRenderer(
            paragraph: block,
            styles: styles,
            contentWidth: contentWidth ?? MediaQuery.of(context).size.width,
          );
        } else if (block is TableModel) {
          return TableRenderer(
            table: block,
            styles: styles,
            contentWidth: contentWidth ?? MediaQuery.of(context).size.width,
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
