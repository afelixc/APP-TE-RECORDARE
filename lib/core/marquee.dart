import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// En las pruebas el texto no se mueve (una animación que nunca termina
/// no deja esperar a que la pantalla quede quieta).
bool marqueeOn = kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

/// Un renglón que, si no entra, se va deslizando de derecha a izquierda,
/// entero, y vuelve a empezar sin parar (pedido del usuario: el nombre de
/// cada recuadro de Notas y Tareas). Si entra, queda quieto.
class Marquee extends StatefulWidget {
  const Marquee(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  static const _gap = 36.0;
  static const _speed = 32.0; // puntos por segundo
  static const _pause = 1500; // milisegundos quieto al principio

  late final AnimationController _c = AnimationController(vsync: this);
  double _loop = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _run(double loop) {
    if (loop == _loop && (_c.isAnimating || loop == 0)) return;
    _loop = loop;
    if (loop == 0) {
      _c.stop();
      return;
    }
    _c.duration = Duration(
      milliseconds: _pause + (loop / _speed * 1000).round(),
    );
    _c.repeat();
  }

  double get _offset {
    final d = _c.duration;
    if (d == null) return 0;
    final ms = _c.value * d.inMilliseconds;
    if (ms <= _pause) return 0;
    return (ms - _pause) / 1000 * _speed;
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, box) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final width = tp.width;
        final height = tp.height;
        tp.dispose();
        final fits = width <= box.maxWidth;
        final loop = fits || !marqueeOn ? 0.0 : width + _gap;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _run(loop);
        });
        if (loop == 0) {
          return Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        final line = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        );
        return Semantics(
          label: widget.text,
          child: ExcludeSemantics(
            child: ClipRect(
              child: SizedBox(
                width: box.maxWidth,
                height: height,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(-_offset, 0),
                    child: child,
                  ),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        line,
                        const SizedBox(width: _gap),
                        line,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
