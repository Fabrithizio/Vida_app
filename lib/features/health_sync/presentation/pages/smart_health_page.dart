// ============================================================================
// FILE: lib/features/health_sync/presentation/pages/smart_health_page.dart
//
// Área de conexão do smartwatch / saúde.
//
// O que faz:
// - mostra estado da conexão
// - permite sincronizar com Health Connect
// - mostra últimos dados recebidos do smartwatch
// - permite desconectar sem apagar o resto do módulo fitness
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
    final snapshot = _snapshot;
    final connected = snapshot?.isConnected ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Conectar saúde / smartwatch'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08101E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: connected
                                ? const Color(0xFF88F089).withOpacity(0.18)
                                : const Color(0xFF78B5FF).withOpacity(0.18),
                            child: Icon(
                              connected
                                  ? Icons.watch_rounded
                                  : Icons.watch_off_rounded,
                              color: connected
                                  ? const Color(0xFF88F089)
                                  : const Color(0xFF78B5FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connected
                                      ? 'Smartwatch conectado'
                                      : 'Smartwatch ainda não conectado',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  snapshot?.platformLabel ?? 'Health Connect',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Última sincronização: ${_formatDate(snapshot?.lastSyncAt)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _syncing ? null : _sync,
                              icon: _syncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      connected
                                          ? Icons.sync_rounded
                                          : Icons.link_rounded,
                                    ),
                              label: Text(
                                connected ? 'Sincronizar agora' : 'Conectar',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: connected ? _disconnect : null,
                            icon: const Icon(Icons.link_off_rounded),
                            label: const Text('Desconectar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _MetricGrid(snapshot: snapshot),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'No Android, o app usa Health Connect para receber dados de sono, exercício, treinos, passos e minutos ativos. O módulo fitness continua com seus registros manuais e agora soma essas leituras automáticas.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snapshot});

  final SmartHealthSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _MetricCard(
          title: 'Sono recente',
          value: snapshot?.sleepHours == null
              ? '—'
              : '${snapshot!.sleepHours!.toStringAsFixed(1).replaceAll('.', ',')}h',
          accent: const Color(0xFFF9C66B),
        ),
        _MetricCard(
          title: 'Exercício 7d',
          value: snapshot?.exerciseMinutes7d == null
              ? '—'
              : '${snapshot!.exerciseMinutes7d!.toStringAsFixed(0)} min',
          accent: const Color(0xFF88F089),
        ),
        _MetricCard(
          title: 'Treinos 7d',
          value: snapshot?.workoutCount7d?.toString() ?? '—',
          accent: const Color(0xFF8E82FF),
        ),
        _MetricCard(
          title: 'Passos hoje',
          value: snapshot?.stepsToday?.toString() ?? '—',
          accent: const Color(0xFF78B5FF),
        ),
        _MetricCard(
          title: 'Min ativos hoje',
          value: snapshot?.activeMinutesToday?.toString() ?? '—',
          accent: const Color(0xFF9EC2FF),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(18),
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
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
