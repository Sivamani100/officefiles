import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../word_engine/parser/docx_parser.dart';
import '../word_engine/renderer/document_renderer.dart';
import '../word_engine/renderer/pagination_engine.dart';
import '../word_engine/model/document_model.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  DocumentModel? _document;
  bool _loading = false;
  String? _error;
  int _pageCount = 0;

  Future<void> _pickAndLoad() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );
    if (result == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw Exception('Unable to load file bytes.');
      }
      final document = await compute(_parseDocx, bytes);

      // Count total pages across all sections
      int totalPages = 0;
      for (final section in document.sections) {
        totalPages += PaginationEngine.paginate(
          section,
          document.styles,
          document.numbering,
          document.abstractNumbering,
        ).length;
      }

      setState(() {
        _document = document;
        _pageCount = totalPages;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static Future<DocumentModel> _parseDocx(Uint8List bytes) async {
    return DocxParser(bytes).parse();
  }

  @override
  Widget build(BuildContext context) {
    final title = _document != null
        ? 'Word Viewer ($_pageCount pages)'
        : 'Word Viewer';

    return Scaffold(
      backgroundColor: const Color(0xFF525659),
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _document == null
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2D32),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFF4A4E55),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2196F3).withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.description_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Offline Word Engine',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select a Word (.docx) document to render it offline with high fidelity.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _pickAndLoad,
                              icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
                              label: const Text(
                                'Select Document',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFF1E88E5).withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                      child: InteractiveViewer(
                        minScale: 0.3,
                        maxScale: 4.0,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        constrained: false,
                        child: Center(
                          child: DocumentRenderer(document: _document!),
                        ),
                      ),
                    ),
    );
  }
}
