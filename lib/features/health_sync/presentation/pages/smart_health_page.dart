// ============================================================================
// FILE: lib/features/health_sync/presentation/pages/smart_health_page.dart
//
// Tela enxuta de conexão do smartwatch.
//
// Estratégia desta versão:
// - conexão simples por Health Connect
// - foco nos 4 dados principais: sono, passos, atividade e calorias
// - dados secundários ficam escondidos em uma área expansível
// - sem prometer QR mágico; a conexão real mais fácil no Android é 1 toque
//   com Health Connect e permissões corretas
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../health_sync_service.dart';

class SmartHealthPage extends StatefulWidget {
  const SmartHealthPage({super.key});

  @override
  State<SmartHealthPage> createState() => _SmartHealthPageState();
}

class _SmartHealthPageState extends State<SmartHealthPage> {
  final SmartHealthSyncService _service = SmartHealthSyncService();

  bool _loading = true;
  bool _syncing = false;
  SmartHealthSnapshot? _snapshot;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await _service.readSnapshot(_uid);
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final result = await _service.sync(_uid);
    if (!mounted) return;
    setState(() => _syncing = false);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _disconnect() async {
    await _service.disconnect(_uid);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Conexão removida do app.')));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nunca';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$d/$m/$y às $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        _snapshot ??
        const SmartHealthSnapshot(
          isConnected: false,
          platformLabel: 'Health Connect',
        );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Smartwatch & conexão'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _HeroCard(
                  connected: snapshot.isConnected,
                  platformLabel: snapshot.platformLabel,
                  lastSyncText: _formatDate(snapshot.lastSyncAt),
                  syncing: _syncing,
                  onSync: _sync,
                  onDisconnect: snapshot.isConnected ? _disconnect : null,
                ),
                const SizedBox(height: 14),
                _QuickCompatibilityCard(snapshot: snapshot),
                const SizedBox(height: 14),
                _PrimaryMetrics(snapshot: snapshot),
                const SizedBox(height: 14),
                _HiddenDetails(snapshot: snapshot),
                const SizedBox(height: 14),
                _ConnectStepsCard(),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.connected,
    required this.platformLabel,
    required this.lastSyncText,
    required this.syncing,
    required this.onSync,
    required this.onDisconnect,
  });

  final bool connected;
  final String platformLabel;
  final String lastSyncText;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: connected
              ? const [Color(0xFF0B3A2A), Color(0xFF0C5A43), Color(0xFF10785A)]
              : const [Color(0xFF141B2B), Color(0xFF102744), Color(0xFF20395E)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withOpacity(0.12),
                ),
                child: Icon(
                  connected ? Icons.watch_rounded : Icons.watch_off_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Conexão pronta' : 'Conectar em 1 toque',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected
                          ? 'O app já pode puxar dados reais do Health Connect.'
                          : 'A forma mais simples no Android é conectar pelo Health Connect.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: connected ? 'Ativo' : 'Desconectado',
                color: connected
                    ? const Color(0xFF7DF0A6)
                    : const Color(0xFF8AB6FF),
              ),
              _StatusPill(label: platformLabel, color: const Color(0xFFFFD47A)),
              _StatusPill(
                label: 'Última sync: $lastSyncText',
                color: const Color(0xFFE6E6E6),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: syncing ? null : onSync,
                  icon: syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          connected ? Icons.sync_rounded : Icons.link_rounded,
                        ),
                  label: Text(
                    connected ? 'Sincronizar agora' : 'Conectar agora',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onDisconnect,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Remover'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickCompatibilityCard extends StatelessWidget {
  const _QuickCompatibilityCard({required this.snapshot});

  final SmartHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C111C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compatibilidade simples',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Funciona melhor com relógios Android cujos apps enviam dados para o Health Connect. Samsung, Xiaomi e outros entram aqui quando o app companheiro compartilha os dados.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.35,
            ),
          ),
          if (!snapshot.isConnected) ...[
            const SizedBox(height: 10),
            Text(
              'Não usamos QR code aqui porque ele não resolve a parte real da permissão. O caminho mais estável é tocar em conectar e liberar o acesso.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.58),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryMetrics extends StatelessWidget {
  const _PrimaryMetrics({required this.snapshot});

  final SmartHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.28,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _MetricCard(
          title: 'Passos hoje',
          value: snapshot.stepsToday?.toString() ?? '—',
          hint: 'fonte real do relógio / Health Connect',
          accent: const Color(0xFF78B5FF),
        ),
        _MetricCard(
          title: 'Sono recente',
          value: snapshot.sleepHours == null
              ? '—'
              : '${snapshot.sleepHours!.toStringAsFixed(1).replaceAll('.', ',')}h',
          hint: 'última sessão relevante',
          accent: const Color(0xFFF9C66B),
        ),
        _MetricCard(
          title: 'Atividade hoje',
          value: snapshot.activeMinutesToday == null
              ? '—'
              : '${snapshot.activeMinutesToday} min',
          hint: 'movimento detectado hoje',
          accent: const Color(0xFF88F089),
        ),
        _MetricCard(
          title: 'Calorias ativas',
          value: snapshot.activeCaloriesToday == null
              ? '—'
              : '${snapshot.activeCaloriesToday} kcal',
          hint: 'gasto ativo do dia',
          accent: const Color(0xFF8E82FF),
        ),
      ],
    );
  }
}

class _HiddenDetails extends StatelessWidget {
  const _HiddenDetails({required this.snapshot});

  final SmartHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C111C),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          title: const Text(
            'Detalhes secundários',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            'Treinos e leitura complementar ficam aqui, fora da vitrine principal.',
            style: TextStyle(color: Colors.white.withOpacity(0.62)),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: 'Exercício 7d',
                    value: snapshot.exerciseMinutes7d == null
                        ? '—'
                        : '${snapshot.exerciseMinutes7d!.toStringAsFixed(0)} min',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetric(
                    label: 'Treinos 7d',
                    value: snapshot.workoutCount7d?.toString() ?? '—',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectStepsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como conectar sem complicar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          const _StepRow(
            index: 1,
            text:
                'No Android, deixe o app do relógio já configurado normalmente.',
          ),
          const _StepRow(
            index: 2,
            text:
                'Toque em conectar agora e libere as permissões no Health Connect.',
          ),
          const _StepRow(
            index: 3,
            text:
                'Volte aqui para sincronizar e ver passos, sono, atividade e calorias.',
          ),
          const SizedBox(height: 10),
          Text(
            'O app usa o caminho mais estável para Android. Não depende de marca específica e não precisa entrar em Apple Health.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.hint,
    required this.accent,
  });

  final String title;
  final String value;
  final String hint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(
              color: Colors.white.withOpacity(0.52),
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF35D26F).withOpacity(0.18),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF88F089),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.74),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
