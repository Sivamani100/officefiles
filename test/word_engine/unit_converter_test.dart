import 'package:flutter_test/flutter_test.dart';
import 'package:officefiles/word_engine/utils/unit_converter.dart';

void main() {
  test('DXA to pixels conversion', () {
    expect(UnitConverter.dxaToPx(1440), 96.0);
  });

  test('EMU to pixels conversion', () {
    expect(UnitConverter.emuToPx(914400), 96.0);
  });

  test('Half-point to font size', () {
    expect(UnitConverter.halfPointToFontSize(24), 12.0);
  });
}
