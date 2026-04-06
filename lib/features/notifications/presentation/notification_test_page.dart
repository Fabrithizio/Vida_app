import 'package:flutter/material.dart';
import 'package:vida_app/features/notifications/application/notification_service.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  String _status = 'Nenhum teste executado ainda.';
  bool _loading = false;

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      setState(() {
        _loading = true;
        _status = 'Executando...';
      });

      await action();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _status = successMessage;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _status = 'Erro: $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao testar notificação: $e')));
    }
  }

  Future<void> _checkPending() async {
    try {
      setState(() {
        _loading = true;
        _status = 'Lendo notificações pendentes...';
      });

      final pending = await NotificationService.instance.pendingRequests();

      if (!mounted) return;

      final text = pending.isEmpty
          ? 'Não há notificações pendentes.'
          : 'Pendentes: ${pending.map((e) => e.id).join(', ')}';

      setState(() {
        _loading = false;
        _status = text;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _status = 'Erro ao ler pendentes: $e';
      });
    }
  }

  Widget _fullButton({
    required String text,
    required Future<void> Function() onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : () => _run(onPressed, text),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teste de Notificações')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_status, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 16),
            _fullButton(
              text: 'Enviar notificação agora',
              onPressed: NotificationService.instance.showTestNow,
            ),
            const SizedBox(height: 12),
            _fullButton(
              text: 'Teste com delay simples (5s)',
              onPressed: NotificationService
                  .instance
                  .showDelayedForegroundTestIn5Seconds,
            ),
            const SizedBox(height: 12),
            _fullButton(
              text: 'Teste com agendamento real (10s)',
              onPressed:
                  NotificationService.instance.showScheduledTestIn10Seconds,
            ),
            const SizedBox(height: 12),
            _fullButton(
              text: 'Teste estilo timeline',
              onPressed:
                  NotificationService.instance.showTimelineStyleTestIn10Seconds,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _checkPending,
                child: const Text('Ver notificações pendentes'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => _run(
                        NotificationService.instance.cancelTestNotifications,
                        'Notificações de teste canceladas.',
                      ),
                child: const Text('Cancelar notificações de teste'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Leitura do teste:\n'
              '- Se "agora" funciona e "delay simples" funciona, o app consegue notificar.\n'
              '- Se "agendamento real" falha, o problema está no agendamento do Android.\n'
              '- Se "timeline" falha, o problema está no fluxo da timeline/agendamento.',
            ),
          ],
        ),
      ),
    );
  }
}
