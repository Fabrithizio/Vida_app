import 'package:flutter/material.dart';

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.isIncomeCategory,
  });

  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final bool isIncomeCategory;

  Color get color => Color(colorValue);

  IconData get icon {
    switch (iconKey) {
      case 'work':
        return Icons.work_outline;
      case 'food':
        return Icons.restaurant_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'leisure':
        return Icons.sports_esports_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'income':
        return Icons.add_card_outlined;
      case 'expense':
        return Icons.receipt_long_outlined;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  FinanceCategory copyWith({
    String? id,
    String? name,
    String? iconKey,
    int? colorValue,
    bool? isIncomeCategory,
  }) {
    return FinanceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      isIncomeCategory: isIncomeCategory ?? this.isIncomeCategory,
    );
  }
}
