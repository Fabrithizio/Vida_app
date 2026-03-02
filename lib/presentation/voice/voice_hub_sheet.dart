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
  String _finalText = '';
  String _lastWords = '';

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

    // Não inicia automaticamente se quiser controlar manualmente:
    if (ok) {
      await _start();
    }
  }

  Future<void> _start() async {
    if (!_available) return;

    setState(() {
      _listening = true;
      _partial = '';
      _finalText = '';
      _lastWords = '';
      _resultMessage = null;
    });

    await _speech.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 25),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;

        setState(() {
          _partial = words;
          _lastWords = words;
          if (result.finalResult) {
            _finalText = words;
          }
        });
      },
    );
  }

  Future<void> _stopAndHandle() async {
    if (!_listening) return;

    await _speech.stop();

    if (!mounted) return;
    setState(() => _listening = false);

    final transcript = _pickBestTranscript();
    if (transcript.isEmpty) {
      setState(
        () => _resultMessage =
            'Não captei nada. Tente novamente (e confira a permissão do microfone).',
      );
      return;
    }

    // 1) Se parecer evento, tenta abrir confirmação editável (reduz pressão)
    final handledByDialog = await _tryEventDialogFlow(transcript);
    if (handledByDialog) return;

    // 2) Caso contrário, delega ao router (compras / outros)
    final res = await widget.router.handle(transcript);
    if (!mounted) return;

    setState(() => _resultMessage = res.message);

    if (res.handled) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _pickBestTranscript() {
    final t = _finalText.trim();
    if (t.isNotEmpty) return t;

    final p = _partial.trim();
    if (p.isNotEmpty) return p;

    return _lastWords.trim();
  }

  Future<bool> _tryEventDialogFlow(String transcript) async {
    final lower = transcript.toLowerCase();

    final looksEvent = RegExp(
      r'^(agendar|marcar|evento|compromisso|colocar na agenda|por na agenda|criar lembrete|lembrete)\b',
      caseSensitive: false,
    ).hasMatch(transcript);

    if (!looksEvent) return false;

    // precisa de data dd/MM (ou dd/MM/yyyy) e hora (HH:mm ou 10h/10 horas)
    final dm = RegExp(r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?').firstMatch(lower);
    final hm = RegExp(r'(\d{1,2})\s*[:h]\s*(\d{2})').firstMatch(lower);
    final hOnly = RegExp(r'\b(\d{1,2})\s*(?:h\b|horas?\b)').firstMatch(lower);

    if (dm == null || (hm == null && hOnly == null)) {
      // se não der pra inferir, deixa o router tentar (ou mostrar msg)
      return false;
    }

    final now = DateTime.now();
    final day = int.parse(dm.group(1)!);
    final month = int.parse(dm.group(2)!);
    final yearStr = dm.group(3);

    final year = (yearStr == null || yearStr.isEmpty)
        ? now.year
        : (yearStr.length == 2
              ? 2000 + int.parse(yearStr)
              : int.parse(yearStr));

    final hour = hm != null
        ? int.parse(hm.group(1)!)
        : int.parse(hOnly!.group(1)!);
    final minute = hm != null ? int.parse(hm.group(2)!) : 0;

    final startGuess = DateTime(year, month, day, hour, minute);

    var titleGuess = transcript
        .replaceAll(
          RegExp(
            r'^(agendar|marcar|evento|compromisso|lembrete)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\d{1,2}/\d{1,2}(?:/\d{2,4})?'), '')
        .replaceAll(RegExp(r'\d{1,2}\s*[:h]\s*\d{2}'), '')
        .replaceAll(
          RegExp(r'\b\d{1,2}\s*(?:h|horas?)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (titleGuess.isEmpty) titleGuess = 'Evento';

    final ok = await _openEventConfirmDialog(
      initialTitle: titleGuess,
      initialStart: startGuess,
    );

    if (!ok) return true; // fluxo do evento foi tratado (cancelou)
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) Navigator.of(context).pop();
    return true;
  }

  Future<bool> _openEventConfirmDialog({
    required String initialTitle,
    required DateTime initialStart,
  }) async {
    final titleCtrl = TextEditingController(text: initialTitle);
    final date = ValueNotifier<DateTime>(
      DateTime(initialStart.year, initialStart.month, initialStart.day),
    );
    final time = ValueNotifier<TimeOfDay>(
      TimeOfDay(hour: initialStart.hour, minute: initialStart.minute),
    );

    bool saved = false;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: date,
                      builder: (context, d, child) => OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: d,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) date.value = picked;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ValueListenableBuilder<TimeOfDay>(
                      valueListenable: time,
                      builder: (context, t, child) => OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: t,
                          );
                          if (picked != null) time.value = picked;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      );

      if (result != true) return false;

      final d = date.value;
      final t = time.value;

      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final hh = t.hour.toString().padLeft(2, '0');
      final mi = t.minute.toString().padLeft(2, '0');

      // Reaproveita o router (ele cria duração padrão, checa conflito, etc.)
      final fixedTranscript =
          'agendar evento ${titleCtrl.text} dia $dd/$mm às $hh:$mi';
      final res = await widget.router.handle(fixedTranscript);

      if (!mounted) return false;
      setState(() => _resultMessage = res.message);

      saved = res.handled;
      return saved;
    } finally {
      titleCtrl.dispose();
      date.dispose();
      time.dispose();
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
