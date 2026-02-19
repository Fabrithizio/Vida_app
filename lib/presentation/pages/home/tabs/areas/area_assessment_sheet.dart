// lib/presentation/pages/home/tabs/areas/area_assessment_sheet.dart
import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_assessment.dart';
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
    _status = widget.initial?.status ?? AreaStatus.bom;
    _reason = TextEditingController(text: widget.initial?.reason ?? '');
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    final reason = _reason.text.trim();
    if (_status == AreaStatus.ruim && reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se for "Ruim", escreva o motivo.')),
      );
      return;
    }

    Navigator.of(context).pop(
      AreaAssessmentResult(
        assessment: AreaAssessment(
          status: _status,
          reason: _status == AreaStatus.ruim ? reason : null,
        ),
      ),
    );
  }

  void _clear() {
    Navigator.of(context).pop(
      const AreaAssessmentResult(
        assessment: AreaAssessment(status: AreaStatus.bom),
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
              ButtonSegment(value: AreaStatus.otimo, label: Text('Ótimo')),
              ButtonSegment(value: AreaStatus.bom, label: Text('Bom')),
              ButtonSegment(value: AreaStatus.ruim, label: Text('Ruim')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: 12),
          if (_status == AreaStatus.ruim)
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Por que está ruim?',
                border: OutlineInputBorder(),
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
