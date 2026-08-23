import 'package:flutter/material.dart';

import '../model/image_model.dart';
import '../utils/unit_converter.dart';

class ImageRenderer {
  /// Renders an inline image from an [ImageModel].
  /// Falls back to a placeholder icon if the image fails to decode.
  static Widget buildInlineImage(ImageModel image) {
    final width = UnitConverter.emuToPx(image.widthEmu);
    final height = UnitConverter.emuToPx(image.heightEmu);

    return Image.memory(
      image.bytes,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }
}
