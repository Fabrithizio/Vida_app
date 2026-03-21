import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StatusSvgOverlay extends StatelessWidget {
  const StatusSvgOverlay({
    super.key,
    required this.svgAsset,
    required this.fillsById,
    this.fillOpacity = 0.35,
  });

  final String svgAsset;

  /// Mapa: id do SVG -> cor (sem alpha; alpha é controlado por fillOpacity)
  final Map<String, Color> fillsById;

  final double fillOpacity;

  String _hex(Color c) {
    final r = c.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = c.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = c.b.toInt().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  String _applyFillToId(String svg, String id, Color color) {
    // tenta achar tags comuns com id="..."
    final re = RegExp(
      r'(<(path|rect|circle|ellipse|polygon|polyline)\b[^>]*\bid="' +
          RegExp.escape(id) +
          r'"[^>]*)(/?>)',
      caseSensitive: false,
    );

    return svg.replaceAllMapped(re, (m) {
      var head = m.group(1)!;
      final tail = m.group(3)!;

      // remove fill / fill-opacity existentes nessa tag
      head = head
          .replaceAll(RegExp(r'\sfill="[^"]*"', caseSensitive: false), '')
          .replaceAll(RegExp(r"\sfill='[^']*'", caseSensitive: false), '')
          .replaceAll(
            RegExp(r'\sfill-opacity="[^"]*"', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(r"\sfill-opacity='[^']*'", caseSensitive: false),
            '',
          );

      final fill = _hex(color);
      final op = fillOpacity.clamp(0.0, 1.0);

      return '$head fill="$fill" fill-opacity="$op"$tail';
    });
  }

  Future<String> _buildSvg() async {
    var svg = await rootBundle.loadString(svgAsset);

    // garante que o SVG não venha com fill global matando nossos fills
    // (se houver style global, não tem como cobrir 100% sem parser XML; MVP ok)

    for (final e in fillsById.entries) {
      svg = _applyFillToId(svg, e.key, e.value);
    }

    return svg;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _buildSvg(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: true,
          child: SvgPicture.string(snap.data!, fit: BoxFit.contain),
        );
      },
    );
  }
}
