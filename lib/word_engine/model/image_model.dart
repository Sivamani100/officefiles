import 'dart:typed_data';

class ImageModel {
  final Uint8List bytes;
  final int widthEmu;
  final int heightEmu;
  final String? wrapType;
  final int? positionXEmu;
  final int? positionYEmu;
  final String? relativeFromH;
  final String? alignH;
  final String? relativeFromV;
  final String? alignV;

  ImageModel({
    required this.bytes,
    required this.widthEmu,
    required this.heightEmu,
    this.wrapType,
    this.positionXEmu,
    this.positionYEmu,
    this.relativeFromH,
    this.alignH,
    this.relativeFromV,
    this.alignV,
  });
}
