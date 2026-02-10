import 'package:flutter/material.dart';

class DayTab extends StatelessWidget {
  const DayTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Meu Dia (Timeline)\n\nAqui vai a timeline do dia.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
