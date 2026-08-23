import 'package:xml/xml.dart';
import '../utils/xml_extensions.dart';

class RelationshipParser {
  static Map<String, String> parse(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final result = <String, String>{};
    for (final rel in document.findAllElementsNS('Relationship')) {
      final id = rel.getAttributeNS('Id');
      final target = rel.getAttributeNS('Target');
      if (id == null || target == null) continue;
      var resolved = target;
      if (!resolved.startsWith('/') && !resolved.startsWith('word/')) {
        resolved = 'word/$resolved';
      }
      result[id] = resolved;
    }
    return result;
  }
}
