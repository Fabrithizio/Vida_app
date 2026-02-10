import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

class BodyMapHit {
  const BodyMapHit({required this.id});
  final String id;
}

class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.imageAsset,
    required this.overlaySvgAsset,
    this.onHit,
  });

  final String imageAsset;
  final String overlaySvgAsset;
  final ValueChanged<BodyMapHit>? onHit;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  _SvgModel? _model;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final xmlText = await rootBundle.loadString(widget.overlaySvgAsset);
    final doc = XmlDocument.parse(xmlText);

    final svg = doc.findAllElements('svg').first;
    final viewBox = svg.getAttribute('viewBox') ?? '0 0 800 1328';
    final parts = viewBox.split(RegExp(r'\s+'));
    final vbW = double.parse(parts[2]);
    final vbH = double.parse(parts[3]);

    final ellipses = <_Ellipse>[];
    for (final el in doc.findAllElements('ellipse')) {
      final id = el.getAttribute('id');
      if (id == null || id.isEmpty) continue;

      final cx = double.parse(el.getAttribute('cx') ?? '0');
      final cy = double.parse(el.getAttribute('cy') ?? '0');
      final rx = double.parse(el.getAttribute('rx') ?? '0');
      final ry = double.parse(el.getAttribute('ry') ?? '0');

      ellipses.add(_Ellipse(id: id, cx: cx, cy: cy, rx: rx, ry: ry));
    }

    setState(() {
      _model = _SvgModel(viewBoxW: vbW, viewBoxH: vbH, ellipses: ellipses);
    });
  }

  String? _hitTest(Size size, Offset localPos) {
    final model = _model;
    if (model == null) return null;

    final x = localPos.dx * model.viewBoxW / size.width;
    final y = localPos.dy * model.viewBoxH / size.height;

    for (final e in model.ellipses) {
      final dx = x - e.cx;
      final dy = y - e.cy;
      final v = (dx * dx) / (e.rx * e.rx) + (dy * dy) / (e.ry * e.ry);
      if (v <= 1.0) return e.id;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;

    if (model == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspect = model.viewBoxW / model.viewBoxH;

    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);

          return GestureDetector(
            onTapDown: (d) {
              final id = _hitTest(size, d.localPosition);
              if (id == null) return;

              setState(() => _selectedId = id);
              widget.onHit?.call(BodyMapHit(id: id));
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(widget.imageAsset, fit: BoxFit.cover),
                CustomPaint(
                  painter: _OverlayPainter(
                    model: model,
                    selectedId: _selectedId,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SvgModel {
  const _SvgModel({
    required this.viewBoxW,
    required this.viewBoxH,
    required this.ellipses,
  });

  final double viewBoxW;
  final double viewBoxH;
  final List<_Ellipse> ellipses;
}

class _Ellipse {
  const _Ellipse({
    required this.id,
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
  });

  final String id;
  final double cx;
  final double cy;
  final double rx;
  final double ry;
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.model, required this.selectedId});

  final _SvgModel model;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedId == null) return;

    final scaleX = size.width / model.viewBoxW;
    final scaleY = size.height / model.viewBoxH;

    final e = model.ellipses.where((x) => x.id == selectedId).firstOrNull;
    if (e == null) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, size.shortestSide * 0.006);

    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(e.cx, e.cy),
        width: e.rx * 2,
        height: e.ry * 2,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
