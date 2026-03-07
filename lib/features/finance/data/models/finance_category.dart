import 'package:flutter/material.dart';

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.isIncomeCategory,
  });

  final String id;
  final String name;
  final IconData icon;
  final int colorValue;
  final bool isIncomeCategory;

  Color get color => Color(colorValue);

  FinanceCategory copyWith({
    String? id,
    String? name,
    IconData? icon,
    int? colorValue,
    bool? isIncomeCategory,
  }) {
    return FinanceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      isIncomeCategory: isIncomeCategory ?? this.isIncomeCategory,
    );
  }
}
