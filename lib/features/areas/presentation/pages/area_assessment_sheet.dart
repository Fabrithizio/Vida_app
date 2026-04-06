// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/area_assessment_sheet.dart
//
// O que esse arquivo faz:
// - Abre o bottom sheet para o usuário escolher o status manual de uma subárea
// - Permite escrever o motivo quando o status exige explicação
// - Retorna uma AreaAssessment pronta para salvar
//
// Atualização:
// - removido AreaStatus.attention
// - adaptado para o sistema novo:
//   Ótimo / Bom / Médio / Ruim / Crítico
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';

class AreaAssessmentResult {
  const AreaAssessmentResult({required this.assessment, this.clear = false});

  final AreaAssessment assessment;
  final bool clear;
}

class AreaAssessmentSheet extends StatefulWidget {
  const AreaAssessmentSheet({super.key, required this.title, this.initial});

  final String title;
  final AreaAssessment? initial;

  @override
  State<AreaAssessmentSheet> createState() => _AreaAssessmentSheetState();
}

class _AreaAssessmentSheetState extends State<AreaAssessmentSheet> {
  late AreaStatus _status;
  late final TextEditingController _reason;

  @override
  void initState() {
    super.initState();
    _status = widget.initial?.status ?? AreaStatus.noData;
    _reason = TextEditingController(text: widget.initial?.reason ?? '');
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _needsReason =>
      _status == AreaStatus.medium ||
      _status == AreaStatus.poor ||
      _status == AreaStatus.critical;

  String get _reasonLabel {
    switch (_status) {
      case AreaStatus.critical:
        return 'Por que está crítico?';
      case AreaStatus.poor:
        return 'Por que está ruim?';
      case AreaStatus.medium:
        return 'Por que está médio?';
      case AreaStatus.excellent:
      case AreaStatus.good:
      case AreaStatus.noData:
        return 'Motivo';
    }
  }

  void _save() {
    final reason = _reason.text.trim();

    if (_needsReason && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva o motivo para esse status.')),
      );
      return;
    }

    Navigator.of(context).pop(
      AreaAssessmentResult(
        assessment: AreaAssessment(
          status: _status,
          reason: reason.isEmpty ? null : reason,
          source: AreaDataSource.manual,
          lastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _clear() {
    Navigator.of(context).pop(
      const AreaAssessmentResult(
        assessment: AreaAssessment(
          status: AreaStatus.noData,
          source: AreaDataSource.manual,
        ),
        clear: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<AreaStatus>(
            segments: const [
              ButtonSegment<AreaStatus>(
                value: AreaStatus.excellent,
                label: Text('Ótimo'),
                icon: Icon(Icons.sentiment_very_satisfied_rounded),
              ),
              ButtonSegment<AreaStatus>(
                value: AreaStatus.good,
                label: Text('Bom'),
                icon: Icon(Icons.thumb_up_alt_rounded),
              ),
              ButtonSegment<AreaStatus>(
                value: AreaStatus.medium,
                label: Text('Médio'),
                icon: Icon(Icons.remove_circle_outline_rounded),
              ),
              ButtonSegment<AreaStatus>(
                value: AreaStatus.poor,
                label: Text('Ruim'),
                icon: Icon(Icons.error_outline_rounded),
              ),
              ButtonSegment<AreaStatus>(
                value: AreaStatus.critical,
                label: Text('Crítico'),
                icon: Icon(Icons.warning_amber_rounded),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (selection) {
              setState(() => _status = selection.first);
            },
          ),
          const SizedBox(height: 12),
          if (_needsReason)
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _reasonLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
