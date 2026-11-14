import 'package:flutter/material.dart';

/// La letra más grande (hasta 14) en la que todos los textos entran en
/// [width], para que botones vecinos tengan el mismo tamaño de letra.
double sameFontSize(
  BuildContext context,
  List<String> texts,
  double width, {
  FontWeight weight = FontWeight.w500,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  var size = 14.0;
  for (final t in texts) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        // Con la misma letra que usa la pantalla.
        style: DefaultTextStyle.of(context).style
            .copyWith(fontSize: 14, fontWeight: weight),
      ),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (tp.width > width && width > 0) {
      size = size < 14 * width / tp.width ? size : 14 * width / tp.width;
    }
    tp.dispose();
  }
  return size;
}
