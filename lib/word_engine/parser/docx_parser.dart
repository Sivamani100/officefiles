import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:archive/archive.dart';
import '../utils/xml_extensions.dart';

import '../model/document_model.dart';
import '../model/style_model.dart';
import '../model/numbering_model.dart';
import 'document_parser.dart';
import 'relationship_parser.dart';
import 'styles_parser.dart';
import 'theme_parser.dart';
import 'numbering_parser.dart';

class DocxParser {
  final List<int> fileBytes;
  late final Archive _archive;

  DocxParser(this.fileBytes) {
    _archive = ZipDecoder().decodeBytes(fileBytes);
  }

  ArchiveFile? _findFile(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    // Try exact match first
    for (final file in _archive.files) {
      final fileName = file.name.replaceAll('\\', '/').toLowerCase();
      if (fileName == normalized) {
        return file;
      }
    }
    // Try matching without leading slash or relative to word/
    for (final file in _archive.files) {
      final fileName = file.name.replaceAll('\\', '/').toLowerCase();
      final targetNoSlash = normalized.startsWith('/') ? normalized.substring(1) : normalized;
      final fileNoSlash = fileName.startsWith('/') ? fileName.substring(1) : fileName;
      if (fileNoSlash == targetNoSlash) {
        return file;
      }
      if (fileNoSlash == 'word/$targetNoSlash' || targetNoSlash == 'word/$fileNoSlash') {
        return file;
      }
    }
    return null;
  }

  String? readFile(String path) {
    final file = _findFile(path);
    if (file == null) return null;
    try {
      return utf8.decode(file.content as List<int>);
    } catch (_) {
      // Fallback to Latin1 if UTF-8 fails
      return latin1.decode(file.content as List<int>);
    }
  }

  Uint8List? readBinaryFile(String path) {
    final file = _findFile(path);
    if (file == null) return null;
    return Uint8List.fromList(file.content as List<int>);
  }

  List<String> listFiles({String prefix = ''}) {
    return _archive.files
        .where((f) => f.name.startsWith(prefix))
        .map((f) => f.name)
        .toList();
  }

  Future<DocumentModel> parse() async {
    final relsXml = readFile('word/_rels/document.xml.rels');
    final documentXml = readFile('word/document.xml');

    String? stylesPath;
    String? numberingPath;
    String? themePath;

    if (relsXml != null) {
      try {
        final doc = XmlDocument.parse(relsXml);
        for (final rel in doc.findAllElements('Relationship', namespace: '*')) {
          final type = rel.getAttribute('Type');
          final target = rel.getAttribute('Target');
          if (type != null && target != null) {
            final resolved = target.replaceAll('\\', '/');
            final zipPath = resolved.startsWith('/')
                ? resolved.substring(1)
                : (resolved.startsWith('word/') ? resolved : 'word/$resolved');

            if (type.endsWith('/styles')) {
              stylesPath = zipPath;
            } else if (type.endsWith('/numbering')) {
              numberingPath = zipPath;
            } else if (type.endsWith('/theme')) {
              themePath = zipPath;
            }
          }
        }
      } catch (_) {}
    }

    stylesPath ??= 'word/styles.xml';
    numberingPath ??= 'word/numbering.xml';
    themePath ??= 'word/theme/theme1.xml';

    final stylesXml = readFile(stylesPath);
    final numberingXml = readFile(numberingPath);
    final themeXml = readFile(themePath);
    final settingsXml = readFile('word/settings.xml');

    bool differentOddEven = false;
    bool mirrorMargins = false;
    if (settingsXml != null) {
      try {
        final doc = XmlDocument.parse(settingsXml);
        if (doc.findAllElementsNS('evenAndOddHeaders').isNotEmpty) {
          differentOddEven = true;
        }
        if (doc.findAllElementsNS('mirrorMargins').isNotEmpty) {
          mirrorMargins = true;
        }
      } catch (_) {}
    }

    final relationships = relsXml != null
        ? RelationshipParser.parse(relsXml)
        : <String, String>{};
    final theme = themeXml != null ? ThemeParser.parse(themeXml) : null;
    final styles = stylesXml != null ? StylesParser.parse(stylesXml, theme: theme) : <String, StyleModel>{};
    final numberingResult = numberingXml != null ? NumberingParser.parse(numberingXml, theme: theme) : NumberingParseResult(numbering: {}, abstractNumbering: {});

    final document = documentXml != null
        ? DocumentParser.parse(
            documentXml,
            styles: styles,
            numbering: numberingResult.numbering,
            abstractNumbering: numberingResult.abstractNumbering,
            theme: theme,
            relationships: relationships,
            readBinaryFile: readBinaryFile,
            differentOddEvenDefault: differentOddEven,
            mirrorMarginsDefault: mirrorMargins,
          )
        : DocumentModel.empty();

    return document;
  }
}
