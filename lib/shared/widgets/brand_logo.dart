import 'package:flutter/material.dart';

/// The BAID X logo trimmed to its visible artwork.
///
/// `baid_x_logo.png` is 1280×960 with the mark centred in empty space
/// (roughly x 213–1093, y 360–577). This clips to that area so the logo can
/// sit at a predictable size. The wordmark is white: place it on ink.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.width = 160, super.key});

  final double width;

  static const _image = Size(1280, 960);
  static const _art = Rect.fromLTRB(213, 360, 1093, 577);

  @override
  Widget build(BuildContext context) {
    final scale = width / _art.width;
    return Semantics(
      label: 'BAID X',
      image: true,
      child: SizedBox(
        width: width,
        height: _art.height * scale,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(-_art.left * scale, -_art.top * scale),
              child: Image.asset(
                'assets/images/logo/baid_x_logo.png',
                width: _image.width * scale,
                height: _image.height * scale,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
