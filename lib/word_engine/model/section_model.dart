import 'header_footer_model.dart';

class SectionModel {
  final int pageWidthDxa;
  final int pageHeightDxa;
  final int marginTopDxa;
  final int marginBottomDxa;
  final int marginLeftDxa;
  final int marginRightDxa;
  final int headerDistanceDxa;
  final int footerDistanceDxa;
  final bool differentFirstPage;
  final bool differentOddEven;
  final bool mirrorMargins;
  final HeaderFooterModel? defaultHeader;

  double get pageWidthPx => pageWidthDxa / 1440 * 96;
  double get pageHeightPx => pageHeightDxa / 1440 * 96;
  double get contentWidthPx => pageWidthPx - marginLeftPx - marginRightPx;
  double get contentHeightPx => pageHeightPx - marginTopPx - marginBottomPx;
  double get marginLeftPx => marginLeftDxa / 1440 * 96;
  double get marginRightPx => marginRightDxa / 1440 * 96;
  double get marginTopPx => marginTopDxa / 1440 * 96;
  double get marginBottomPx => marginBottomDxa / 1440 * 96;
  final HeaderFooterModel? firstPageHeader;
  final HeaderFooterModel? oddHeader;
  final HeaderFooterModel? evenHeader;
  final HeaderFooterModel? defaultFooter;
  final HeaderFooterModel? firstPageFooter;
  final HeaderFooterModel? oddFooter;
  final HeaderFooterModel? evenFooter;
  final List<dynamic> blocks;

  SectionModel({
    required this.pageWidthDxa,
    required this.pageHeightDxa,
    required this.marginTopDxa,
    required this.marginBottomDxa,
    required this.marginLeftDxa,
    required this.marginRightDxa,
    required this.headerDistanceDxa,
    required this.footerDistanceDxa,
    this.differentFirstPage = false,
    this.differentOddEven = false,
    this.mirrorMargins = false,
    this.defaultHeader,
    this.firstPageHeader,
    this.oddHeader,
    this.evenHeader,
    this.defaultFooter,
    this.firstPageFooter,
    this.oddFooter,
    this.evenFooter,
    List<dynamic>? blocks,
  }) : blocks = blocks ?? [];
}
