import 'package:flutter_test/flutter_test.dart';
import 'package:officefiles/word_engine/parser/relationship_parser.dart';

void main() {
  test('Relationship parser resolves word paths', () {
    final xml = '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
</Relationships>
''';
    final result = RelationshipParser.parse(xml);
    expect(result['rId1'], 'word/media/image1.png');
    expect(result['rId2'], 'word/header1.xml');
  });
}
