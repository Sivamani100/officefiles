import 'package:flutter/material.dart';

import 'image_model.dart';
import 'style_model.dart';

enum RunType { text, tab, lineBreak, pageBreak, image, symbol }

class RunModel {
  final String text;
  final RunType type;
  final String? fontAscii;
  final String? fontHAnsi;
  final String? fontCS;
  final String? rStyle;
  final int? fontSizeHalfPt;
  final bool? bold;
  final bool? italic;
  final bool? boldCs;
  final bool? italicCs;
  final bool? rtl;
  final UnderlineType? underline;
  final Color? underlineColor;
  final bool? strikethrough;
  final bool? doubleStrikethrough;
  final Color? color;
  final Color? highlight;
  final Color? background;
  final VerticalAlignment? vertAlign;
  final bool? allCaps;
  final bool? smallCaps;
  final bool? shadow;
  final bool? outline;
  final bool? vanish;
  final int? characterSpacingTwentieths;
  final ImageModel? image;
  final String? symbolFont;
  final int? symbolCharCode;
  final String? fieldCode;
  final String? hyperlinkId;
  final String? hyperlinkAnchor;

  RunModel({
    this.text = '',
    this.type = RunType.text,
    this.fontAscii,
    this.fontHAnsi,
    this.fontCS,
    this.rStyle,
    this.fontSizeHalfPt,
    this.bold,
    this.italic,
    this.boldCs,
    this.italicCs,
    this.rtl,
    this.underline,
    this.underlineColor,
    this.strikethrough,
    this.doubleStrikethrough,
    this.color,
    this.highlight,
    this.background,
    this.vertAlign,
    this.allCaps,
    this.smallCaps,
    this.shadow,
    this.outline,
    this.vanish,
    this.characterSpacingTwentieths,
    this.image,
    this.symbolFont,
    this.symbolCharCode,
    this.fieldCode,
    this.hyperlinkId,
    this.hyperlinkAnchor,
  });

  RunModel copyWithFieldCode(String? code) {
    return RunModel(
      text: text,
      type: type,
      fontAscii: fontAscii,
      fontHAnsi: fontHAnsi,
      fontCS: fontCS,
      rStyle: rStyle,
      fontSizeHalfPt: fontSizeHalfPt,
      bold: bold,
      italic: italic,
      boldCs: boldCs,
      italicCs: italicCs,
      rtl: rtl,
      underline: underline,
      underlineColor: underlineColor,
      strikethrough: strikethrough,
      doubleStrikethrough: doubleStrikethrough,
      color: color,
      highlight: highlight,
      background: background,
      vertAlign: vertAlign,
      allCaps: allCaps,
      smallCaps: smallCaps,
      shadow: shadow,
      outline: outline,
      vanish: vanish,
      characterSpacingTwentieths: characterSpacingTwentieths,
      image: image,
      symbolFont: symbolFont,
      symbolCharCode: symbolCharCode,
      fieldCode: code,
      hyperlinkId: hyperlinkId,
      hyperlinkAnchor: hyperlinkAnchor,
    );
  }

  RunModel copyWithHyperlink({String? rId, String? anchor}) {
    return RunModel(
      text: text,
      type: type,
      fontAscii: fontAscii,
      fontHAnsi: fontHAnsi,
      fontCS: fontCS,
      rStyle: rStyle,
      fontSizeHalfPt: fontSizeHalfPt,
      bold: bold,
      italic: italic,
      boldCs: boldCs,
      italicCs: italicCs,
      rtl: rtl,
      underline: underline,
      underlineColor: underlineColor,
      strikethrough: strikethrough,
      doubleStrikethrough: doubleStrikethrough,
      color: color,
      highlight: highlight,
      background: background,
      vertAlign: vertAlign,
      allCaps: allCaps,
      smallCaps: smallCaps,
      shadow: shadow,
      outline: outline,
      vanish: vanish,
      characterSpacingTwentieths: characterSpacingTwentieths,
      image: image,
      symbolFont: symbolFont,
      symbolCharCode: symbolCharCode,
      fieldCode: fieldCode,
      hyperlinkId: rId,
      hyperlinkAnchor: anchor,
    );
  }
}
