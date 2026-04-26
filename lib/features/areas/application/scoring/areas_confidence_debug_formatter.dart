// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_confidence_debug_formatter.dart
//
// O que faz:
// - Formata o resultado do AreasConfidenceEngine para debug rápido
// - Ajuda a entender por que um score final ficou mais alto ou mais baixo
// ============================================================================

import 'package:vida_app/features/areas/application/scoring/areas_confidence_engine.dart';

class AreasConfidenceDebugFormatter {
  const AreasConfidenceDebugFormatter();

  String format(ConfidenceBreakdown breakdown) {
    return 'Bruto ${breakdown.rawScore} | '
        'Fonte ${breakdown.sourceWeight.toStringAsFixed(2)} | '
        'Recência ${breakdown.recencyWeight.toStringAsFixed(2)} | '
        'Consistência ${breakdown.consistencyWeight.toStringAsFixed(2)} | '
        'Completude ${breakdown.completenessWeight.toStringAsFixed(2)} | '
        'Final ${breakdown.finalScore}';
  }
}
