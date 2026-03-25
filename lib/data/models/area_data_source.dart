enum AreaDataSource {
  manual,
  onboarding,
  dailyQuestions,
  automatic,
  estimated,
  mixed,
  unknown,
}

extension AreaDataSourceUi on AreaDataSource {
  String get label {
    switch (this) {
      case AreaDataSource.manual:
        return 'Manual';
      case AreaDataSource.onboarding:
        return 'Onboarding';
      case AreaDataSource.dailyQuestions:
        return 'Perguntas diárias';
      case AreaDataSource.automatic:
        return 'Automático';
      case AreaDataSource.estimated:
        return 'Estimado';
      case AreaDataSource.mixed:
        return 'Misto';
      case AreaDataSource.unknown:
        return 'Desconhecida';
    }
  }

  static AreaDataSource fromStorage(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'manual':
        return AreaDataSource.manual;
      case 'onboarding':
        return AreaDataSource.onboarding;
      case 'dailyQuestions':
        return AreaDataSource.dailyQuestions;
      case 'automatic':
        return AreaDataSource.automatic;
      case 'estimated':
        return AreaDataSource.estimated;
      case 'mixed':
        return AreaDataSource.mixed;
      default:
        return AreaDataSource.unknown;
    }
  }

  String get storageName {
    switch (this) {
      case AreaDataSource.manual:
        return 'manual';
      case AreaDataSource.onboarding:
        return 'onboarding';
      case AreaDataSource.dailyQuestions:
        return 'dailyQuestions';
      case AreaDataSource.automatic:
        return 'automatic';
      case AreaDataSource.estimated:
        return 'estimated';
      case AreaDataSource.mixed:
        return 'mixed';
      case AreaDataSource.unknown:
        return 'unknown';
    }
  }
}
