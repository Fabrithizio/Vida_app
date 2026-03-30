import 'package:flutter/material.dart';
import 'package:vida_app/features/device/device_usage_service.dart';

class UsageAccessOverlay extends StatefulWidget {
  const UsageAccessOverlay({super.key, required this.onGranted});

  final Future<void> Function() onGranted;

  @override
  State<UsageAccessOverlay> createState() => _UsageAccessOverlayState();
}

class _UsageAccessOverlayState extends State<UsageAccessOverlay> {
  final DeviceUsageService _usage = DeviceUsageService();
  bool _checking = false;

  Future<void> _openSettings() async {
    await _usage.openUsageAccessSettings();
  }

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final ok = await _usage.hasUsageAccess();
      if (!mounted) return;

      if (ok) {
        await widget.onGranted();
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ainda falta ativar o Acesso de uso para este app.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Container(
            width: 360,
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1225),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x65000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, color: Colors.white, size: 34),
                const SizedBox(height: 10),
                const Text(
                  'Permissão necessária',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para preencher automaticamente Tempo de Tela, Redes Sociais e Uso Noturno, o Android exige ativar o “Acesso de uso” para este app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_rounded,
                            color: Colors.white.withValues(alpha: 0.80),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Configurações → Acesso especial → Acesso de uso → Ativar para Vida',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _checking ? null : _openSettings,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Abrir configurações',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _checking ? null : _recheck,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _checking ? 'Verificando...' : 'Já ativei',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Obs: o Android não permite ativar isso sozinho — você confirma nessa tela.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
