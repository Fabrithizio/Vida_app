import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vida_app/services/voice/voice_command_router.dart';

class VoiceHubSheet extends StatefulWidget {
  const VoiceHubSheet({super.key, required this.router});
  final VoiceCommandRouter router;

  @override
  State<VoiceHubSheet> createState() => _VoiceHubSheetState();
}

class _VoiceHubSheetState extends State<VoiceHubSheet> {
  final SpeechToText _speech = SpeechToText();

  bool _available = false;
  bool _listening = false;
  String _partial = '';
  String _final = '';
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initSpeech);
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize();
    if (!mounted) return;
    setState(() => _available = ok);
    if (ok) await _start();
  }

  Future<void> _start() async {
    if (!_available) return;

    setState(() {
      _listening = true;
      _partial = '';
      _final = '';
      _resultMessage = null;
    });

    await _speech.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 10),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (r) {
        setState(() {
          _partial = r.recognizedWords;
          if (r.finalResult) _final = r.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopAndHandle() async {
    if (!_listening) return;
    await _speech.stop();
    setState(() => _listening = false);

    final transcript = (_final.isNotEmpty ? _final : _partial).trim();
    final res = await widget.router.handle(transcript);
    if (!mounted) return;

    setState(() => _resultMessage = res.message);

    if (res.handled) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint =
        'Dicas:\n'
        '• Compras: “adicionar na lista ovos, banana, pão”\n'
        '• Evento: “agendar evento aniversário dia 23/03 às 10:00”\n'
        '• Use vírgulas para separar itens.\n';

    final title = _listening ? 'Ouvindo…' : 'Comando de voz';
    final text = (_partial.isNotEmpty ? _partial : hint);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_listening ? Icons.mic : Icons.mic_none),
              title: Text(title),
              subtitle: Text(
                _available
                    ? 'pt-BR • toque em Parar quando terminar'
                    : 'Reconhecimento indisponível',
              ),
              trailing: IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text),
                    if (_resultMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _resultMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _listening ? _stopAndHandle : _start,
                    icon: Icon(_listening ? Icons.stop : Icons.play_arrow),
                    label: Text(_listening ? 'Parar e processar' : 'Ouvir'),
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
