import 'package:flutter/material.dart';

import '../model/document_model.dart';
import '../utils/numbering_formatter.dart';
import 'page_renderer.dart';
import 'pagination_engine.dart';

class DocumentRenderer extends StatelessWidget {
  final DocumentModel document;
  final void Function(String? url, String? anchor)? onHyperlinkTap;

  const DocumentRenderer({
    super.key,
    required this.document,
    this.onHyperlinkTap,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-compute numbering labels for the entire document so counters
    // flow correctly across page boundaries.
    final numberingLabels = NumberingFormatter.computeAllLabels(
      document.sections,
      document.numbering,
      document.abstractNumbering,
      document.styles,
    );

    final allPages = <Widget>[];

    int globalBlockOffset = 0;
    for (final section in document.sections) {
      final pages = PaginationEngine.paginate(
        section,
        document.styles,
        document.numbering,
        document.abstractNumbering,
      );

      for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        allPages.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: RepaintBoundary(
              child: PageRenderer(
                section: section,
                pageContent: pages[pageIndex],
                pageIndex: pageIndex,
                totalPages: pages.length,
                styles: document.styles,
                numbering: document.numbering,
                abstractNumbering: document.abstractNumbering,
                precomputedLabels: numberingLabels,
                blockIndexOffset: globalBlockOffset,
                onHyperlinkTap: onHyperlinkTap,
              ),
            ),
          ),
        );

        // Advance offset by the number of blocks on this page
        globalBlockOffset += pages[pageIndex].blocks.length;
      }
    }

    return Column(children: allPages);
  }

  /// Returns the total number of pages across all sections.
  int totalPageCount() {
    int count = 0;
    for (final section in document.sections) {
      count += PaginationEngine.paginate(
        section,
        document.styles,
        document.numbering,
        document.abstractNumbering,
      ).length;
    }
    return count;
  }
}
