// ============================================================================
// FILE: lib/features/alerts/presentation/widgets/alerts_bell_button.dart
//
// O que este arquivo faz:
// - Widget reutilizável para o sininho com badge
// - Pode ser usado no topo da área, home, perfil ou qualquer outro lugar
// - Abre a central de alertas do app
// - Suporta modo compacto para encaixar no HUD pequeno da aba Áreas
// - Faz deep link direto para páginas importantes quando o alerta é tocado
//
// Ajustes desta versão:
// - respeita readKey contextual ao marcar leitura
// - abre saúde e check-in diário de forma mais direta
// - trata aniversário como atalho para a Linha da Vida
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/life_alert.dart';
import 'package:vida_app/features/alerts/life_alerts_service.dart';
import 'package:vida_app/features/alerts/presentation/pages/alerts_center_page.dart';
import 'package:vida_app/features/areas/presentation/areas_catalog.dart';
import 'package:vida_app/features/areas/presentation/pages/area_detail_page.dart';
import 'package:vida_app/features/areas/presentation/pages/daily_checkin_sheet.dart';
import 'package:vida_app/features/areas/presentation/widgets/areas_model_assets.dart';
import 'package:vida_app/features/body_care/presentation/pages/body_care_page.dart';
import 'package:vida_app/features/goals/presentation/pages/goals_hub_page.dart';
import 'package:vida_app/features/health_sync/presentation/pages/smart_health_page.dart';
import 'package:vida_app/features/life_journey/presentation/pages/life_journey_page.dart';

class AlertsBellButton extends StatefulWidget {
  const AlertsBellButton({
    super.key,
    required this.service,
    this.onOpenRoute,
    this.monthlyBudget,
    this.monthSpending,
    this.iconColor = Colors.white,
    this.compact = false,
  });

  final LifeAlertsService service;
  final ValueChanged<String>? onOpenRoute;
  final double? monthlyBudget;
  final double? monthSpending;
  final Color iconColor;
  final bool compact;

  @override
  State<AlertsBellButton> createState() => _AlertsBellButtonState();
}

class _AlertsBellButtonState extends State<AlertsBellButton> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  @override
  void didUpdateWidget(covariant AlertsBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final count = await widget.service.unreadCount(
      now: DateTime.now(),
      monthlyBudget: widget.monthlyBudget,
      monthSpending: widget.monthSpending,
    );
    if (!mounted) return;
    setState(() => _unread = count);
  }

  Future<void> _open() async {
    final selectedAlert = await Navigator.of(context).push<LifeAlert>(
      MaterialPageRoute(
        builder: (context) => AlertsCenterPage(
          service: widget.service,
          onOpenRoute: widget.onOpenRoute,
          monthlyBudget: widget.monthlyBudget,
          monthSpending: widget.monthSpending,
        ),
      ),
    );

    await _loadUnread();

    if (!mounted || selectedAlert == null) return;

    await _handleSelectedAlert(selectedAlert);
    await _loadUnread();
  }

  Future<void> _handleSelectedAlert(LifeAlert alert) async {
    switch (alert.type) {
      case LifeAlertType.overdueCheckup:
      case LifeAlertType.staleArea:
        await _openAreaAlert(alert);
        return;
      case LifeAlertType.bodyCarePending:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const BodyCarePage()));
        return;
      case LifeAlertType.lifeJourneyUnlocked:
      case LifeAlertType.birthdayCelebration:
        await _openLifeJourneyAlert();
        return;
      case LifeAlertType.goalMomentum:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const GoalsHubPage()));
        return;
      case LifeAlertType.dailyCheckinPending:
      case LifeAlertType.badCheckinStreak:
        await showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const DailyCheckinSheet(),
        );
        return;
      case LifeAlertType.healthSyncDisconnected:
      case LifeAlertType.healthSyncStale:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SmartHealthPage()),
        );
        return;
      default:
        final route = alert.routeHint;
        if (route != null &&
            route.trim().isNotEmpty &&
            widget.onOpenRoute != null) {
          widget.onOpenRoute!(route);
        }
        return;
    }
  }

  Future<void> _openAreaAlert(LifeAlert alert) async {
    final areaId =
        (alert.metadata['areaId'] as String?)?.trim().isNotEmpty == true
        ? alert.metadata['areaId'] as String
        : (alert.areaId ?? '').trim();

    if (areaId.isEmpty) {
      if (widget.onOpenRoute != null && (alert.routeHint ?? '').isNotEmpty) {
        widget.onOpenRoute!(alert.routeHint!);
      }
      return;
    }

    final itemId = (alert.metadata['itemId'] as String?)?.trim();
    final def = AreasCatalog.byId(areaId);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AreaDetailPage(
          areaId: areaId,
          title: def.title,
          initialItemId: itemId == null || itemId.isEmpty ? null : itemId,
        ),
      ),
    );
  }

  Future<void> _openLifeJourneyAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final birthRaw =
        prefs.getString('birth_date_$uid') ??
        prefs.getString('$uid:birthDate') ??
        prefs.getString('$uid:birthdate') ??
        prefs.getString('$uid:dateOfBirth') ??
        prefs.getString('$uid:dob');

    final birthDate = birthRaw == null || birthRaw.trim().isEmpty
        ? null
        : DateTime.tryParse(birthRaw.trim());

    if (birthDate == null) {
      if (widget.onOpenRoute != null) {
        widget.onOpenRoute!('life_journey');
      }
      return;
    }

    final rawGender = (prefs.getString('$uid:gender') ?? '')
        .trim()
        .toLowerCase();
    final sex = rawGender.contains('mulher') || rawGender.contains('femin')
        ? UserSex.female
        : UserSex.male;

    final display = (user.displayName ?? '').trim();
    final email = (user.email ?? '').trim();
    final userName = display.isNotEmpty
        ? display
        : (email.contains('@') ? email.split('@').first : 'Usuário');

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            LifeJourneyPage(userName: userName, sex: sex, birthDate: birthDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.notifications_active_rounded,
          color: widget.iconColor,
          size: widget.compact ? 19 : 24,
        ),
        if (_unread > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF060A14), width: 1.2),
              ),
              constraints: BoxConstraints(
                minWidth: widget.compact ? 15 : 16,
                minHeight: widget.compact ? 15 : 16,
              ),
              child: Text(
                _unread > 9 ? '9+' : '$_unread',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 8 : 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.compact) {
      return GestureDetector(
        onTap: _open,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(width: 28, height: 28, child: Center(child: icon)),
      );
    }

    return IconButton(tooltip: 'Alertas', onPressed: _open, icon: icon);
  }
}
