import 'numbering_model.dart';
import 'section_model.dart';
import 'style_model.dart';
import 'theme_model.dart';

class DocumentModel {
  final List<SectionModel> sections;
  final Map<String, StyleModel> styles;
  final Map<String, NumberingDefinition> numbering;
  final Map<String, AbstractNumDefinition> abstractNumbering;
  final ThemeModel? theme;

  DocumentModel({
    required this.sections,
    required this.styles,
    required this.numbering,
    required this.abstractNumbering,
    this.theme,
  });

  factory DocumentModel.empty() {
    return DocumentModel(
      sections: [],
      styles: {},
      numbering: {},
      abstractNumbering: {},
      theme: null,
    );
  }
}
