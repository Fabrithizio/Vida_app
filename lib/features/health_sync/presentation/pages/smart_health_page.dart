// ============================================================================
// FILE: lib/features/health_sync/presentation/pages/smart_health_page.dart
//
// O que faz:
// - Mostra o ponto central de conexão com smartwatch / saúde
// - Permite conectar e sincronizar dados de saúde no app
// - Exibe um resumo do que foi sincronizado
//
// Nesta versão:
// - o melhor lugar escolhido foi o Perfil, porque é uma configuração do usuário
// - o foco inicial é sincronizar sono e exercício
// - os dados sincronizados já começam a alimentar Corpo & Saúde automaticamente
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:vida_app/features/health_sync/health_sync_service.dart';

class SmartHealthPage extends StatefulWidget {
  const SmartHealthPage({super.key});

  @override
  State<SmartHealthPage> createState() => _SmartHealthPageState();
}

class _SmartHealthPageState extends State<SmartHealthPage> {
  final SmartHealthSyncService _service = SmartHealthSyncService();
  final User? _user = FirebaseAuth.instance.currentUser;

  bool _busy = false;
  SmartHealthSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) return;
    final snapshot = await _service.readSnapshot(user.uid);
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  Future<void> _sync() async {
    final user = _user;
    if (user == null || _busy) return;

    setState(() => _busy = true);
    final result = await _service.sync(user.uid);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _disconnect() async {
    final user = _user;
    if (user == null || _busy) return;

    setState(() => _busy = true);
    await _service.disconnect(user.uid);
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conexão local removida. As permissões do sistema continuam no Health Connect / Apple Health.'),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Saúde conectada'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.watch_rounded, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot?.platformLabel ?? 'Saúde conectada',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot?.isConnected == true
                            ? 'Conexão salva no app e pronta para sincronizar.'
                            : 'Conecte seu telefone ao Health Connect / Apple Health para alimentar Corpo & Saúde automaticamente.',
                        style: const TextStyle(color: Colors.white70, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'O que entra agora no app',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
const Text(
  '• Sono da última sessão sincronizada\n'
  '• Minutos de exercício dos últimos 7 dias\n'
  '• Quantidade de treinos dos últimos 7 dias\n'
  '\n'
  'Nesta primeira versão, o app começa usando isso principalmente em Corpo & Saúde, com foco em Sono e Movimento.',
  style: TextStyle(color: Colors.white70, height: 1.45),
),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumo sincronizado',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoRow(label: 'Plataforma', value: snapshot?.platformLabel ?? '—'),
                _InfoRow(label: 'Conectado', value: snapshot?.isConnected == true ? 'Sim' : 'Não'),
                _InfoRow(label: 'Última sincronização', value: _formatDate(snapshot?.lastSyncAt)),
                _InfoRow(
                  label: 'Sono',
                  value: snapshot?.sleepHours == null
                      ? '—'
                      : '${snapshot!.sleepHours!.toStringAsFixed(1)} h',
                ),
                _InfoRow(
                  label: 'Exercício (7 dias)',
                  value: snapshot?.exerciseMinutes7d == null
                      ? '—'
                      : '${snapshot!.exerciseMinutes7d!.toStringAsFixed(0)} min',
                ),
                _InfoRow(
                  label: 'Treinos (7 dias)',
                  value: snapshot?.workoutCount7d?.toString() ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _busy ? null : _sync,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(snapshot?.isConnected == true ? 'Sincronizar agora' : 'Conectar e sincronizar'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _disconnect,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Remover conexão local'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'No Android, o app usa o Health Connect. Em Android 14+ ele já pode vir integrado ao sistema; em Android 13 ou inferior, pode ser necessário instalar o app Health Connect e liberar as permissões. No iPhone, a integração usa Apple Health.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
