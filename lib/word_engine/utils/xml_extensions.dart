import 'package:xml/xml.dart';

extension XmlDocumentExtension on XmlDocument {
  XmlElement? getElementNS(String name) {
    return getElement(name, namespace: '*');
  }

  Iterable<XmlElement> findAllElementsNS(String name) {
    return findAllElements(name, namespace: '*');
  }

  Iterable<XmlElement> findElementsNS(String name) {
    return findElements(name, namespace: '*');
  }
}

extension XmlElementExtension on XmlElement {
  XmlElement? getElementNS(String name) {
    return getElement(name, namespace: '*');
  }

  Iterable<XmlElement> findAllElementsNS(String name) {
    return findAllElements(name, namespace: '*');
  }

  Iterable<XmlElement> findElementsNS(String name) {
    return findElements(name, namespace: '*');
  }

  String? getAttributeNS(String name) {
    for (final attr in attributes) {
      if (attr.name.local == name) {
        return attr.value;
      }
    }
    return null;
  }
}
