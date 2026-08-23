class ThemeModel {
  final Map<String, int> colors;
  final String? majorFont;
  final String? minorFont;

  ThemeModel({
    required this.colors,
    this.majorFont,
    this.minorFont,
  });

  /// Resolves theme values like 'minorHAnsi', 'minorAscii', etc.
  /// to the theme's defined major or minor typeface.
  String? resolveThemeFont(String? themeValue) {
    if (themeValue == null) return null;
    final val = themeValue.toLowerCase();
    if (val.contains('major')) {
      return majorFont;
    } else if (val.contains('minor')) {
      return minorFont;
    }
    return null;
  }
}
