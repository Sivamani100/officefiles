import 'package:xml/xml.dart';
import '../utils/xml_extensions.dart';

import '../model/header_footer_model.dart';
import '../model/section_model.dart';

class SectionParser {
  static SectionModel parse(
    XmlElement sectPr, {
    HeaderFooterModel? defaultHeader,
    HeaderFooterModel? defaultFooter,
  }) {
    final pgSz = sectPr.getElementNS('pgSz');
    final pgMar = sectPr.getElementNS('pgMar');
    final width = int.tryParse(pgSz?.getAttribute('w') ?? '11906') ?? 11906;
    final height = int.tryParse(pgSz?.getAttribute('h') ?? '16838') ?? 16838;
    final top = int.tryParse(pgMar?.getAttribute('top') ?? '1440') ?? 1440;
    final bottom = int.tryParse(pgMar?.getAttribute('bottom') ?? '1440') ?? 1440;
    final left = int.tryParse(pgMar?.getAttribute('left') ?? '1440') ?? 1440;
    final right = int.tryParse(pgMar?.getAttribute('right') ?? '1440') ?? 1440;
    final headerDist = int.tryParse(pgMar?.getAttribute('header') ?? '720') ?? 720;
    final footerDist = int.tryParse(pgMar?.getAttribute('footer') ?? '720') ?? 720;

    return SectionModel(
      pageWidthDxa: width,
      pageHeightDxa: height,
      marginTopDxa: top,
      marginBottomDxa: bottom,
      marginLeftDxa: left,
      marginRightDxa: right,
      headerDistanceDxa: headerDist,
      footerDistanceDxa: footerDist,
      differentFirstPage: false,
      differentOddEven: false,
      defaultHeader: defaultHeader,
      defaultFooter: defaultFooter,
    );
  }
}
