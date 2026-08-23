import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('XML namespace behavior test', () {
    const xml = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Normal"/>
        <w:jc w:val="center"/>
      </w:pPr>
      <w:r>
        <w:t>Hello World</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>
''';
    final doc = XmlDocument.parse(xml);
    print("findAllElements('body'): \${doc.findAllElements('body')}");
    print("findAllElements('body', namespace: '*'): \${doc.findAllElements('body', namespace: '*')}");
    
    final body = doc.findAllElements('body', namespace: '*').first;
    final p = body.findAllElements('p', namespace: '*').first;
    
    print("p.getElement('pPr'): \${p.getElement('pPr')}");
    print("p.getElement('pPr', namespace: '*'): \${p.getElement('pPr', namespace: '*')}");
    
    final pPr = p.getElement('pPr', namespace: '*');
    if (pPr != null) {
      print("pPr.getElement('pStyle'): \${pPr.getElement('pStyle')}");
      print("pPr.getElement('pStyle', namespace: '*'): \${pPr.getElement('pStyle', namespace: '*')}");
    }
  });
}
