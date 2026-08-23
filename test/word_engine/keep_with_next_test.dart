import 'package:flutter_test/flutter_test.dart';
import 'package:officefiles/word_engine/model/paragraph_model.dart';
import 'package:officefiles/word_engine/model/run_model.dart';
import 'package:officefiles/word_engine/model/section_model.dart';
import 'package:officefiles/word_engine/model/style_model.dart';
import 'package:officefiles/word_engine/renderer/pagination_engine.dart';

void main() {
  testWidgets('keep-with-next pagination backtracking test', (WidgetTester tester) async {
    // Create styles mapping where 'heading1' has keepNext set to true
    final styles = {
      'heading1': StyleModel(
        styleId: 'heading1',
        name: 'heading1',
        type: StyleType.paragraph,
        paragraphProperties: const {
          'keepNext': true,
        },
      ),
    };

    // Create blocks:
    // Block 0: Normal paragraph (fits easily)
    // Block 1: Heading 1 (keepWithNext = true)
    // Block 2: Heading 2 (keepWithNext = true)
    // Block 3: Large paragraph (will cause page overflow)
    final block0 = ParagraphModel(runs: [RunModel(text: 'Introduction')]);
    final block1 = ParagraphModel(styleId: 'heading1', runs: [RunModel(text: 'Chapter Title')]);
    final block2 = ParagraphModel(styleId: 'heading1', runs: [RunModel(text: 'Section Title')]);
    // A paragraph containing multiple lines to guarantee it occupies substantial height
    final block3 = ParagraphModel(runs: [
      RunModel(text: 'This is a long body paragraph text that will overflow the page boundary.'),
      RunModel(text: ' More text to ensure it takes up significant space.'),
    ]);

    // Create section with 1056 dxa page height (small page height to trigger overflow easily)
    final section = SectionModel(
      pageWidthDxa: 11906,
      pageHeightDxa: 3000, // very small page height (~200 pixels)
      marginTopDxa: 720,   // ~50 pixels
      marginBottomDxa: 720,
      marginLeftDxa: 1440,
      marginRightDxa: 1440,
      headerDistanceDxa: 0,
      footerDistanceDxa: 0,
      blocks: [block0, block1, block2, block3],
    );

    // Run pagination
    final pages = PaginationEngine.paginate(section, styles);

    // Under keep-with-next backtracking:
    // - Block 0 goes to Page 1.
    // - Block 1, Block 2, Block 3 must be pushed together to Page 2 (as a kept group)
    //   because Block 3 overflows the space remaining after Block 0, 1, 2 on Page 1.
    expect(pages.length, greaterThanOrEqualTo(2));
    
    // Page 1 should only contain Block 0
    expect(pages[0].blocks.length, equals(1));
    expect(pages[0].blocks[0], equals(block0));

    // Page 2 should start with Block 1 (Heading 1) and keep them together
    expect(pages[1].blocks.length, equals(3));
    expect(pages[1].blocks[0], equals(block1));
    expect(pages[1].blocks[1], equals(block2));
    expect(pages[1].blocks[2], equals(block3));
  });
}
