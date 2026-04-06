import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';

class AreasDeviceUsageEngine {
  Future<AreaAssessment?> computedScreenTime(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:screen_time') ?? '').trim();
    if (raw.isEmpty) return null;

    final hours = _extractScreenTimeHours(raw);
    if (hours == null) {
      return AreaAssessment(
        status: AreaStatus.noData,
        reason: 'Não foi possível interpretar o tempo de tela salvo.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: 'Atualize esse campo em um formato reconhecido.',
      );
    }

    final score = _screenTimeScore(hours);
    final status = _statusFromNumericScore(score);

    final action = switch (status) {
      AreaStatus.excellent => 'Ótimo. Continue protegendo seu tempo de tela.',
      AreaStatus.good => 'Bom. Só monitore para não subir.',
      AreaStatus.medium => 'Tente reduzir um pouco o tempo de tela.',
      AreaStatus.poor => 'Tente reduzir bastante o tempo de tela.',
      AreaStatus.critical => 'Tempo de tela alto. Defina limites diários.',
      AreaStatus.noData => 'Atualize seus dados.',
    };

    return AreaAssessment(
      status: status,
      score: score,
      reason: 'Tempo de tela hoje: $raw.',
      source: AreaDataSource.automatic,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details:
          'Calculado automaticamente a partir do uso total de tela no dia.',
    );
  }

  Future<AreaAssessment?> computedSocialMedia(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:social_media') ?? '').trim();
    if (raw.isEmpty) return null;

    final hours = _extractScreenTimeHours(raw);
    if (hours == null) {
      return AreaAssessment(
        status: AreaStatus.noData,
        reason: 'Não foi possível interpretar o tempo em redes sociais salvo.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: 'Atualize esse campo em um formato reconhecido.',
      );
    }

    final score = _socialMediaScore(hours);
    final status = _statusFromNumericScore(score);

    final action = switch (status) {
      AreaStatus.excellent => 'Ótimo. Continue protegendo seu tempo.',
      AreaStatus.good => 'Bom. Só monitore para não subir.',
      AreaStatus.medium => 'Use com moderação para não subir.',
      AreaStatus.poor => 'Vale reduzir bastante redes sociais.',
      AreaStatus.critical => 'Redes sociais estão pesando. Defina limites.',
      AreaStatus.noData => 'Atualize seus dados.',
    };

    return AreaAssessment(
      status: status,
      score: score,
      reason: 'Tempo em redes sociais hoje: $raw.',
      source: AreaDataSource.automatic,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details:
          'Calculado automaticamente a partir do uso em apps sociais (Facebook, YouTube, WhatsApp, Instagram, TikTok, Kwai, Messenger, X, Telegram).',
    );
  }

  Future<AreaAssessment?> computedNightUse(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:night_use') ?? '').trim();
    if (raw.isEmpty) return null;

    final hours = _extractScreenTimeHours(raw);
    if (hours == null) {
      return AreaAssessment(
        status: AreaStatus.noData,
        reason: 'Não foi possível interpretar o uso noturno salvo.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: 'Atualize esse campo em um formato reconhecido.',
      );
    }

    final score = _nightUseScore(hours);
    final status = _statusFromNumericScore(score);

    final action = switch (status) {
      AreaStatus.excellent => 'Ótimo. Continue protegendo seu descanso.',
      AreaStatus.good => 'Bom. Só evite estender muito à noite.',
      AreaStatus.medium => 'Tente reduzir um pouco a tela perto de dormir.',
      AreaStatus.poor => 'Tente reduzir bastante a tela perto de dormir.',
      AreaStatus.critical => 'Uso noturno alto. Crie um horário de desligar.',
      AreaStatus.noData => 'Atualize seus dados.',
    };

    return AreaAssessment(
      status: status,
      score: score,
      reason: 'Uso noturno (19:00–04:00): $raw.',
      source: AreaDataSource.automatic,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details:
          'Calculado automaticamente somando uso de tela no período 19:00–04:00.',
    );
  }

  double? _extractScreenTimeHours(String raw) {
    final normalized = raw
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(' ', '')
        .toLowerCase();

    if (normalized.startsWith('<')) {
      final value = double.tryParse(
        normalized.replaceAll('<', '').replaceAll('h', ''),
      );
      return value == null ? null : value - 0.1;
    }

    if (normalized.contains('-')) {
      final parts = normalized.replaceAll('h', '').split('-');
      if (parts.length == 2) {
        final a = double.tryParse(parts[0]);
        final b = double.tryParse(parts[1]);
        if (a != null && b != null) return (a + b) / 2;
      }
    }

    if (normalized.startsWith('>=')) {
      final value = double.tryParse(
        normalized.replaceAll('>=', '').replaceAll('h', ''),
      );
      return value;
    }

    if (normalized.startsWith('>')) {
      final value = double.tryParse(
        normalized.replaceAll('>', '').replaceAll('h', ''),
      );
      return value;
    }

    return double.tryParse(normalized.replaceAll('h', ''));
  }

  int _screenTimeScore(double hours) {
    final raw = 100 - ((hours - 2.0) * 14.0);
    return raw.round().clamp(5, 100);
  }

  int _socialMediaScore(double hours) {
    final raw = 100 - ((hours - 1.0) * 18.0);
    return raw.round().clamp(5, 100);
  }

  int _nightUseScore(double hours) {
    final raw = 100 - ((hours - 0.5) * 25.0);
    return raw.round().clamp(5, 100);
  }

  AreaStatus _statusFromNumericScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }
}
