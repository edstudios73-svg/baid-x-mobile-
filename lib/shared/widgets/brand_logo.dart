import 'package:flutter/material.dart';

/// The white BAID X wordmark from the website (assets/logo.png, 870×217).
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.width = 112, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'BAID X',
      image: true,
      child: Image.asset('assets/images/logo/baidx_logo_white.png', width: width, height: width * 217 / 870, fit: BoxFit.contain),
    );
  }
}
