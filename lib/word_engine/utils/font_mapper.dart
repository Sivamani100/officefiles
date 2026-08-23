class FontMapper {
  static const Map<String, String> _fallbackFonts = {
    'Calibri': 'Carlito',
    'Calibri Light': 'Carlito',
    'Cambria': 'Lora',
    'Cambria Math': 'Lora',
    'Times New Roman': 'Tinos',
    'Arial': 'Arimo',
    'Arial Narrow': 'Arimo',
    'Helvetica': 'Arimo',
    'Courier New': 'Cousine',
    'Georgia': 'Lora',
    'Verdana': 'Arimo',
    'Tahoma': 'Arimo',
    'Trebuchet MS': 'Arimo',
    'Century Gothic': 'Outfit',
    'Garamond': 'EB Garamond',
    'Palatino Linotype': 'Lora',
    'Symbol': 'Arimo',
    'Wingdings': 'Arimo',
    'Wingdings 2': 'Arimo',
    'Wingdings 3': 'Arimo',
    'Webdings': 'Arimo',
    'Segoe UI': 'Open Sans',
    'Segoe UI Symbol': 'Open Sans',
    'Consolas': 'Inconsolata',
    'Lucida Console': 'Inconsolata',
    'Comic Sans MS': 'Arimo',
    'Impact': 'Arimo',
    'Book Antiqua': 'Lora',
  };

  /// Resolves a DOCX font name to a Flutter-compatible font family.
  /// Falls back to [fontName] itself if no mapping exists, or 'Roboto' if null/empty.
  static String resolve(String? fontName) {
    if (fontName == null || fontName.isEmpty) return 'Roboto';
    return _fallbackFonts[fontName] ?? fontName;
  }

  /// Resolves a symbol font name, useful for runs of type [RunType.symbol].
  /// Symbol and Wingdings fonts are mapped to fallback fonts.
  static String resolveSymbolFont(String? fontName) {
    if (fontName == null || fontName.isEmpty) return 'Roboto';
    return _fallbackFonts[fontName] ?? fontName;
  }
}
