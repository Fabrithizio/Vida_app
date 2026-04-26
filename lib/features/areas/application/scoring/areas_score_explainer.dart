// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_score_explainer.dart
//
// O que faz:
// - Centraliza textos curtos para explicar o score ao usuário
// - Evita explicações antigas perdidas em várias telas
// - Prepara o detalhe da área para falar a linguagem do sistema novo
// ============================================================================

import 'package:vida_app/data/models/area_data_source.dart';

class AreasScoreExplainer {
  const AreasScoreExplainer();

  String sourceLabel(AreaDataSource source) {
    switch (source) {
      case AreaDataSource.automatic:
        return 'Automático';
      case AreaDataSource.mixed:
        return 'Misto';
      case AreaDataSource.estimated:
        return 'Estimado';
      case AreaDataSource.onboarding:
        return 'Onboarding';
      case AreaDataSource.dailyQuestions:
        return 'Check-in diário';
      case AreaDataSource.manual:
        return 'Manual';
      case AreaDataSource.unknown:
        return 'Origem indefinida';
    }
  }

  String sourceDescription(AreaDataSource source) {
    switch (source) {
      case AreaDataSource.automatic:
        return 'Veio de dado automático e tem peso máximo de confiança.';
      case AreaDataSource.mixed:
        return 'Veio do app misturando dado interno com automação confiável.';
      case AreaDataSource.estimated:
        return 'Foi estimado por sinais cruzados do sistema.';
      case AreaDataSource.onboarding:
        return 'É uma base inicial criada a partir das respostas iniciais.';
      case AreaDataSource.dailyQuestions:
        return 'Veio das respostas adaptativas do check-in diário.';
      case AreaDataSource.manual:
        return 'Veio de registro manual e por isso pesa menos.';
      case AreaDataSource.unknown:
        return 'A origem não foi mapeada corretamente ainda.';
    }
  }

  String recencyLabel(int daysSinceUpdate) {
    if (daysSinceUpdate <= 0) return 'Atualizado hoje';
    if (daysSinceUpdate == 1) return 'Atualizado ontem';
    if (daysSinceUpdate <= 7) return 'Atualização recente';
    if (daysSinceUpdate <= 14) return 'Atualização válida';
    if (daysSinceUpdate <= 30) return 'Atualização envelhecendo';
    return 'Atualização antiga';
  }

  String decayDescription(int daysSinceUpdate) {
    if (daysSinceUpdate <= 14) {
      return 'O score ainda está preservado dentro da janela ativa.';
    }
    final overdue = daysSinceUpdate - 14;
    return 'O score entrou em decaimento há $overdue dia(s) por falta de atualização.';
  }
}
