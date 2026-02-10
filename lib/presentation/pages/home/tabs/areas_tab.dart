import 'package:flutter/material.dart';

import '../../../widgets/body_map.dart';

class AreasTab extends StatelessWidget {
  const AreasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: BodyMap(
              imageAsset: 'assets/images/Modelo_masculino.png',
              overlaySvgAsset: 'assets/images/Modelo_masculino_svg.svg',
              onHit: (hit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Você clicou: ${hit.id}')),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.touch_app),
            title: Text('Dica'),
            subtitle: Text('Toque nas áreas marcadas no SVG (cabeca, peito, bolso...).'),
          ),
        ),
      ],
    );
  }
}
