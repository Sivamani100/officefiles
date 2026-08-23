class UnitConverter {
  static const double screenDpi = 96.0;
  static const double pointsPerInch = 72.0;
  static const double emuPerInch = 914400.0;
  static const double dxaPerInch = 1440.0;

  static double dxaToPx(int dxa) => dxa / dxaPerInch * screenDpi;
  static double emuToPx(int emu) => emu / emuPerInch * screenDpi;
  static double halfPointToPx(int halfPt) => halfPt / 2 * screenDpi / pointsPerInch;
  static double halfPointToFontSize(int halfPt) => halfPt / 2.0;
  static double twentiethsOfPointToPx(int val) => val / 20.0 * screenDpi / pointsPerInch;
  static double pointToPx(double pt) => pt * screenDpi / pointsPerInch;
}
