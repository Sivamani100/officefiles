import 'dart:typed_data';
import 'package:xml/xml.dart';

import '../model/header_footer_model.dart';
import '../model/style_model.dart';
import '../model/numbering_model.dart';
import '../model/theme_model.dart';
import 'document_parser.dart';

class HeaderFooterParser {
  static HeaderFooterModel parse(
    String xmlContent, {
    required Map<String, StyleModel> styles,
    required Map<String, NumberingDefinition> numbering,
    required Map<String, AbstractNumDefinition> abstractNumbering,
    required ThemeModel? theme,
    required Map<String, String> relationships,
    required Uint8List? Function(String path) readBinaryFile,
  }) {
    final document = XmlDocument.parse(xmlContent);
    final root = document.rootElement; // w:hdr or w:ftr
    final blocks = <dynamic>[];

    void extractBlocks(XmlElement parent) {
      for (final child in parent.children.whereType<XmlElement>()) {
        final name = child.name.local;
        if (name == 'p') {
          blocks.add(DocumentParser.parseParagraph(
            child,
            styles: styles,
            numbering: numbering,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
            theme: theme,
          ));
        } else if (name == 'tbl') {
          blocks.add(DocumentParser.parseTable(
            child,
            styles: styles,
            numbering: numbering,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
            theme: theme,
          ));
        } else if (name == 'sdt' || name == 'sdtContent') {
          extractBlocks(child);
        }
      }
    }

    extractBlocks(root);
    return HeaderFooterModel(blocks: blocks);
  }
}
