import 'package:flutter_test/flutter_test.dart';
import 'package:officefiles/word_engine/model/paragraph_model.dart';
import 'package:officefiles/word_engine/parser/styles_parser.dart';
import 'package:officefiles/word_engine/utils/style_resolver.dart';

void main() {
  test('Style numbering resolution test', () {
    const xml = '''
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="ListParagraph">
    <w:name w:val="List Paragraph"/>
    <w:pPr>
      <w:numPr>
        <w:numId w:val="5"/>
        <w:ilvl w:val="2"/>
      </w:numPr>
    </w:pPr>
  </w:style>
</w:styles>
''';

    final styles = StylesParser.parse(xml);
    expect(styles.containsKey('listparagraph'), isTrue);

    final style = styles['listparagraph']!;
    final styleNum = style.paragraphProperties['numbering'];
    expect(styleNum, isNotNull);
    expect(styleNum['numId'], equals('5'));
    expect(styleNum['ilvl'], equals(2));

    // Paragraph using the style
    final paragraph = ParagraphModel(styleId: 'ListParagraph');
    final resolvedNum = StyleResolver.resolveNumbering(paragraph, styles);
    expect(resolvedNum, isNotNull);
    expect(resolvedNum!.numId, equals('5'));
    expect(resolvedNum.ilvl, equals(2));
  });
}
