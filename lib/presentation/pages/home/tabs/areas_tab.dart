import 'package:flutter/material.dart';

import '../../../widgets/body_map.dart';
import 'areas/area_detail_page.dart';

class AreasTab extends StatelessWidget {
  const AreasTab({super.key});

  ({String areaId, String title})? _mapHitToArea(String hitId) {
    final key = hitId.trim().toLowerCase();

    // Ajuste os IDs abaixo para bater com os IDs do seu SVG
    switch (key) {
      case 'cabeca':
      case 'cabeça':
      case 'head':
        return (areaId: 'head', title: 'Cabeça');

      case 'peito':
      case 'torax':
      case 'tórax':
      case 'chest':
        return (areaId: 'chest', title: 'Peito');

      case 'abdomen':
      case 'abdômen':
      case 'barriga':
      case 'stomach':
        return (areaId: 'abdomen', title: 'Abdômen');

      case 'braco_esquerdo':
      case 'braço_esquerdo':
      case 'left_arm':
        return (areaId: 'leftArm', title: 'Braço esquerdo');

      case 'braco_direito':
      case 'braço_direito':
      case 'right_arm':
        return (areaId: 'rightArm', title: 'Braço direito');

      case 'perna_esquerda':
      case 'left_leg':
        return (areaId: 'leftLeg', title: 'Perna esquerda');

      case 'perna_direita':
      case 'right_leg':
        return (areaId: 'rightLeg', title: 'Perna direita');

      default:
        return null;
    }
  }

  void _openArea(
    BuildContext context, {
    required String areaId,
    required String title,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailPage(areaId: areaId, title: title),
      ),
    );
  }

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
                final mapped = _mapHitToArea(hit.id);

                if (mapped == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Área sem configuração: ${hit.id}')),
                  );
                  return;
                }

                _openArea(context, areaId: mapped.areaId, title: mapped.title);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.touch_app),
            title: Text('Dica'),
            subtitle: Text(
              'Toque nas áreas marcadas no SVG (cabeca, peito, abdomen...).',
            ),
          ),
        ),
      ],
    );
  }
}
