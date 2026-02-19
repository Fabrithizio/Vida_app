// lib/data/models/area_assessment.dart
import 'area_status.dart';

class AreaAssessment {
  const AreaAssessment({required this.status, this.reason});

  final AreaStatus status;
  final String? reason;

  Map<String, dynamic> toMap() => {'status': status.name, 'reason': reason};

  static AreaAssessment fromMap(Map<String, dynamic> map) {
    return AreaAssessment(
      status: AreaStatus.values.byName(map['status'] as String),
      reason: map['reason'] as String?,
    );
  }
}
