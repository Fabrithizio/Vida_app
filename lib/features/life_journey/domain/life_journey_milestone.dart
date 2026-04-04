// ============================================================================
// FILE: lib/features/life_journey/domain/life_journey_milestone.dart
//
// O que este arquivo faz:
// - Define o modelo dos marcos da Linha da Vida
// - Centraliza a regra de desbloqueio por idade e por dias extras
// - Facilita adicionar novos conteúdos sem espalhar regra pela UI
// ============================================================================
import 'package:flutter/material.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_model_assets.dart';

enum LifeJourneyMilestoneKind { major, minor }

enum LifeJourneyAudience { everyone, female, male }

class LifeJourneyMilestone {
  const LifeJourneyMilestone._({
    required this.id,
    required this.kind,
    required this.title,
    required this.summary,
    required this.body,
    required this.icon,
    required this.baseAgeYears,
    required this.dayOffset,
    required this.label,
    this.audience = LifeJourneyAudience.everyone,
    this.category = 'Vida',
  });

  factory LifeJourneyMilestone.majorBirthday({
    required String id,
    required String title,
    required String summary,
    required String body,
    required IconData icon,
    required int ageYears,
    String? label,
    LifeJourneyAudience audience = LifeJourneyAudience.everyone,
    String category = 'Marco importante',
  }) {
    return LifeJourneyMilestone._(
      id: id,
      kind: LifeJourneyMilestoneKind.major,
      title: title,
      summary: summary,
      body: body,
      icon: icon,
      baseAgeYears: ageYears,
      dayOffset: 0,
      label: label ?? '$ageYears anos',
      audience: audience,
      category: category,
    );
  }

  factory LifeJourneyMilestone.minorAfterBirth({
    required String id,
    required String title,
    required String summary,
    required String body,
    required IconData icon,
    required int daysSinceBirth,
    String? label,
    LifeJourneyAudience audience = LifeJourneyAudience.everyone,
    String category = 'Dia a dia',
  }) {
    return LifeJourneyMilestone._(
      id: id,
      kind: LifeJourneyMilestoneKind.minor,
      title: title,
      summary: summary,
      body: body,
      icon: icon,
      baseAgeYears: 0,
      dayOffset: daysSinceBirth,
      label: label ?? '$daysSinceBirth dias',
      audience: audience,
      category: category,
    );
  }

  factory LifeJourneyMilestone.minorAfterBirthday({
    required String id,
    required String title,
    required String summary,
    required String body,
    required IconData icon,
    required int ageYears,
    required int daysAfterBirthday,
    String? label,
    LifeJourneyAudience audience = LifeJourneyAudience.everyone,
    String category = 'Dia a dia',
  }) {
    return LifeJourneyMilestone._(
      id: id,
      kind: LifeJourneyMilestoneKind.minor,
      title: title,
      summary: summary,
      body: body,
      icon: icon,
      baseAgeYears: ageYears,
      dayOffset: daysAfterBirthday,
      label: label ?? '$ageYears anos + $daysAfterBirthday dias',
      audience: audience,
      category: category,
    );
  }

  final String id;
  final LifeJourneyMilestoneKind kind;
  final String title;
  final String summary;
  final String body;
  final IconData icon;
  final int baseAgeYears;
  final int dayOffset;
  final String label;
  final LifeJourneyAudience audience;
  final String category;

  bool get isMajor => kind == LifeJourneyMilestoneKind.major;

  bool appliesTo(UserSex sex) {
    switch (audience) {
      case LifeJourneyAudience.everyone:
        return true;
      case LifeJourneyAudience.female:
        return sex == UserSex.female;
      case LifeJourneyAudience.male:
        return sex == UserSex.male;
    }
  }

  DateTime unlockDate(DateTime birthDate) {
    final cleanBirthDate = DateTime(
      birthDate.year,
      birthDate.month,
      birthDate.day,
    );

    final baseDate = _safeDate(
      cleanBirthDate.year + baseAgeYears,
      cleanBirthDate.month,
      cleanBirthDate.day,
    );

    return baseDate.add(Duration(days: dayOffset));
  }

  bool isUnlocked(DateTime birthDate, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return !unlockDate(birthDate).isAfter(today);
  }

  Duration remaining(DateTime birthDate, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return unlockDate(birthDate).difference(today);
  }

  int sortKey() => (baseAgeYears * 366) + dayOffset;

  static DateTime _safeDate(int year, int month, int day) {
    final cappedDay = day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, cappedDay);
  }

  static int _daysInMonth(int year, int month) {
    final firstDayNextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    return firstDayNextMonth.subtract(const Duration(days: 1)).day;
  }
}
