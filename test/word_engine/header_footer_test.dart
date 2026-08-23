import 'package:flutter_test/flutter_test.dart';
import 'package:officefiles/word_engine/model/paragraph_model.dart';
import 'package:officefiles/word_engine/model/table_model.dart';
import 'package:officefiles/word_engine/parser/header_footer_parser.dart';

void main() {
  test('HeaderFooterParser parses paragraphs and tables recursively', () {
    const xml = '''
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:r>
      <w:t>Header Paragraph Text</w:t>
    </w:r>
  </w:p>
  <w:sdt>
    <w:sdtContent>
      <w:tbl>
        <w:tr>
          <w:tc>
            <w:p>
              <w:r>
                <w:t>Table Cell Paragraph</w:t>
              </w:r>
            </w:p>
          </w:tc>
        </w:tr>
      </w:tbl>
    </w:sdtContent>
  </w:sdt>
</w:hdr>
''';

    final model = HeaderFooterParser.parse(
      xml,
      styles: const {},
      numbering: const {},
      abstractNumbering: const {},
      theme: null,
      relationships: const {},
      readBinaryFile: (path) => null,
    );

    expect(model.blocks.length, equals(2));
    expect(model.blocks[0], isA<ParagraphModel>());
    expect(model.blocks[1], isA<TableModel>());

    final paragraph = model.blocks[0] as ParagraphModel;
    expect(paragraph.runs.length, equals(1));
    expect(paragraph.runs[0].text, equals('Header Paragraph Text'));

    final table = model.blocks[1] as TableModel;
    expect(table.rows.length, equals(1));
    expect(table.rows[0].cells.length, equals(1));
    expect(table.rows[0].cells[0].paragraphs.length, equals(1));
    expect(table.rows[0].cells[0].paragraphs[0].runs[0].text, equals('Table Cell Paragraph'));
  });
}
