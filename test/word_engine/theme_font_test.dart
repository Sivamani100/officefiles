import 'package:flutter_test/flutter_test.dart';
import 'package:officefiles/word_engine/model/theme_model.dart';
import 'package:officefiles/word_engine/parser/theme_parser.dart';
import 'package:officefiles/word_engine/parser/styles_parser.dart';

void main() {
  group('Theme font resolution tests', () {
    test('ThemeParser parses major and minor fonts', () {
      const xml = '''
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText"/></a:dk1>
      <a:lt1><a:sysClr val="window"/></a:lt1>
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont>
        <a:latin typeface="Calibri Light"/>
      </a:majorFont>
      <a:minorFont>
        <a:latin typeface="Calibri"/>
      </a:minorFont>
    </a:fontScheme>
  </a:themeElements>
</a:theme>
''';

      final theme = ThemeParser.parse(xml);
      expect(theme.majorFont, equals('Calibri Light'));
      expect(theme.minorFont, equals('Calibri'));

      expect(theme.resolveThemeFont('minorHAnsi'), equals('Calibri'));
      expect(theme.resolveThemeFont('majorAscii'), equals('Calibri Light'));
      expect(theme.resolveThemeFont('unknown'), isNull);
    });

    test('StylesParser resolves theme-based fonts', () {
      final theme = ThemeModel(
        colors: {},
        majorFont: 'Calibri Light',
        minorFont: 'Calibri',
      );

      const stylesXml = '''
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:asciiTheme="minorHAnsi" w:ascii="Times New Roman"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>
''';

      final styles = StylesParser.parse(stylesXml, theme: theme);
      expect(styles.containsKey('docdefaults'), isTrue);

      final docDefaults = styles['docdefaults']!;
      expect(docDefaults.runProperties['fontAscii'], equals('Calibri'));
    });
  });
}
