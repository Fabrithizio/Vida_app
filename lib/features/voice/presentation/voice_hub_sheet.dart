// ============================================================================
// FILE: lib/features/voice/presentation/voice_hub_sheet.dart
//
// O que faz:
// - abre o assistente de voz do app
// - começa a ouvir automaticamente ao abrir
// - processa sozinho quando o usuário para de falar
// - mostra confirmação quando o comando precisa de confirmação
// ============================================================================

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vida_app/features/voice/application/voice_command_router.dart';

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
  bool _processing = false;
  bool _initializing = true;
  bool _processedThisCycle = false;
  bool _autoStartScheduled = false;
  String _bestTranscript = '';

  String _partial = '';
  String _finalText = '';
  String _lastWords = '';
  String? _resultMessage;
  VoiceCommandResult? _pendingConfirmation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _processing = false;
          _initializing = false;
          _resultMessage = 'Erro no microfone: ${error.errorMsg}';
        });
      },
      debugLogging: false,
    );

    if (!mounted) return;
    setState(() {
      _available = available;
      _initializing = false;
    });

    if (_available) {
      _scheduleAutoStart();
    }
  }

  void _scheduleAutoStart() {
    if (_autoStartScheduled) return;
    _autoStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      _autoStartScheduled = false;
      if (!_listening && !_processing && _pendingConfirmation == null) {
        await _start();
      }
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    final done = status == 'done' || status == 'notListening';
    if (done && _listening && !_processing && !_processedThisCycle) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _stopAndHandle(fromStatus: true);
      });
    }
  }

  Future<void> _start() async {
    if (!_available) {
      setState(() {
        _resultMessage =
            'Microfone indisponível. Veja a permissão e tente de novo.';
      });
      return;
    }

    setState(() {
      _listening = true;
      _processing = false;
      _processedThisCycle = false;
      _partial = '';
      _finalText = '';
      _lastWords = '';
      _resultMessage = null;
      _pendingConfirmation = null;
      _bestTranscript = '';
    });

    await _speech.listen(
      localeId: 'pt_BR',
      listenMode: ListenMode.dictation,
      partialResults: true,
      listenOptions: SpeechListenOptions(cancelOnError: true),
      pauseFor: const Duration(milliseconds: 3800),
      listenFor: const Duration(seconds: 45),
      onResult: _onSpeechResult,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords.trim();
    setState(() {
      if (words.length >= _bestTranscript.length) {
        _bestTranscript = words;
      }
      _lastWords = words;
      if (result.finalResult) {
        _finalText = words;
      } else {
        _partial = words;
      }
    });
  }

  Future<void> _stopAndHandle({bool fromStatus = false}) async {
    if (_processing || _processedThisCycle) return;

    _processedThisCycle = true;
    _processing = true;

    if (!fromStatus) {
      await _speech.stop();
    }

    final transcript = _pickBestTranscript();

    if (mounted) {
      setState(() {
        _listening = false;
        _processing = false;
      });
    }

    if (transcript.isEmpty) {
      if (!mounted) return;
      setState(() {
        _resultMessage = 'Não consegui pegar sua fala. Tente de novo.';
      });
      return;
    }

    final result = await widget.router.handle(transcript);
    if (!mounted) return;

    setState(() {
      _resultMessage = result.message;
      _pendingConfirmation = result.requiresConfirmation ? result : null;
    });

    if (result.handled && !result.requiresConfirmation) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmPending() async {
    final pending = _pendingConfirmation;
    if (pending?.onConfirm == null) return;

    setState(() => _processing = true);
    final result = await pending!.onConfirm!();
    if (!mounted) return;

    setState(() {
      _processing = false;
      _pendingConfirmation = null;
      _resultMessage = result.message;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelPending() async {
    final pending = _pendingConfirmation;
    if (pending?.onCancel == null) {
      setState(() => _pendingConfirmation = null);
      return;
    }

    final result = await pending!.onCancel!();
    if (!mounted) return;

    setState(() {
      _pendingConfirmation = null;
      _resultMessage = result.message;
    });
  }

  String _pickBestTranscript() {
    final finalText = _finalText.trim();
    if (finalText.isNotEmpty) return finalText;

    final best = _bestTranscript.trim();
    if (best.isNotEmpty) return best;

    final partial = _partial.trim();
    if (partial.isNotEmpty) return partial;

    return _lastWords.trim();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examples =
        '• “agenda treino amanhã às 7 até 8”\n'
        '• “coloca arroz, leite e ovos na lista”\n'
        '• “adiciona lavar banheiro nas tarefas da casa”\n'
        '• “recebi salário 1200 reais”';

    final title = _initializing
        ? 'Abrindo microfone…'
        : _listening
        ? 'Ouvindo…'
        : _processing
        ? 'Processando…'
        : 'Assistente de voz';

    final heardText = _pickBestTranscript();
    final contentText = heardText.isNotEmpty ? heardText : examples;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening
                      ? const Color(0xFF22C55E).withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                child: Icon(_listening ? Icons.mic : Icons.mic_none),
              ),
              title: Text(title),
              subtitle: Text(
                _available
                    ? 'pt-BR • abriu, falou, ele faz sozinho'
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
                    Text(contentText),
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
                    if (_pendingConfirmation != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _processing ? null : _confirmPending,
                              icon: const Icon(Icons.check),
                              label: Text(
                                _pendingConfirmation!.confirmLabel ??
                                    'Confirmar',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _processing ? null : _cancelPending,
                              icon: const Icon(Icons.close),
                              label: Text(
                                _pendingConfirmation!.cancelLabel ?? 'Cancelar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_pendingConfirmation == null)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _initializing || _processing
                          ? null
                          : (_listening ? () => _stopAndHandle() : _start),
                      icon: Icon(
                        _listening ? Icons.hearing_rounded : Icons.refresh,
                      ),
                      label: Text(
                        _listening
                            ? 'Ouvindo… pode falar'
                            : _initializing
                            ? 'Abrindo...'
                            : 'Ouvir de novo',
                      ),
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
