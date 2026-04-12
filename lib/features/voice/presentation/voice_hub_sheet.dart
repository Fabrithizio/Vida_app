// ============================================================================
// FILE: lib/features/voice/presentation/voice_hub_sheet.dart
//
// O que faz:
// - abre o assistente e já começa a ouvir sozinho
// - processa automaticamente quando o usuário para de falar
// - mostra confirmação quando o comando pede confirmação
// - permite tentar de novo sem fechar o sheet
// ============================================================================

import 'dart:async';

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
  bool _processedThisCycle = false;

  String _partial = '';
  String _finalText = '';
  String _lastWords = '';
  String? _resultMessage;
  VoiceCommandResult? _pendingConfirmation;
  Timer? _autoProcessTimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _processing = false;
          _resultMessage = 'Erro no microfone: ${error.errorMsg}';
        });
      },
      debugLogging: false,
    );
    if (!mounted) return;
    setState(() {});
    if (_available) {
      await _start(auto: true);
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    final done = status == 'done' || status == 'notListening';
    if (done && _listening && !_processing && !_processedThisCycle) {
      _scheduleAutoProcess();
    }
  }

  Future<void> _start({bool auto = false}) async {
    _autoProcessTimer?.cancel();

    if (!_available) {
      setState(() {
        _resultMessage =
            'Microfone indisponível. Veja a permissão e tente de novo.';
      });
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    setState(() {
      _listening = true;
      _processing = false;
      _processedThisCycle = false;
      _partial = '';
      _finalText = '';
      _lastWords = '';
      if (!auto) {
        _resultMessage = null;
        _pendingConfirmation = null;
      }
    });

    await _speech.listen(
      localeId: 'pt_BR',
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      onResult: _onSpeechResult,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _lastWords = result.recognizedWords;
      if (result.finalResult) {
        _finalText = result.recognizedWords;
      } else {
        _partial = result.recognizedWords;
      }
    });

    _autoProcessTimer?.cancel();
    if (result.finalResult) {
      _scheduleAutoProcess(delay: const Duration(milliseconds: 450));
    }
  }

  void _scheduleAutoProcess({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _autoProcessTimer?.cancel();
    _autoProcessTimer = Timer(delay, () {
      if (!mounted) return;
      _stopAndHandle(fromStatus: true);
    });
  }

  Future<void> _stopAndHandle({bool fromStatus = false}) async {
    if (_processing || _processedThisCycle) return;
    _processedThisCycle = true;
    _autoProcessTimer?.cancel();

    if (!fromStatus && _speech.isListening) {
      await _speech.stop();
    }

    final transcript = _pickBestTranscript();
    if (!mounted) return;

    setState(() {
      _listening = false;
      _processing = true;
    });

    if (transcript.isEmpty) {
      setState(() {
        _processing = false;
        _resultMessage = 'Não consegui pegar sua fala. Tente de novo.';
      });
      return;
    }

    final res = await widget.router.handle(transcript);
    if (!mounted) return;

    setState(() {
      _processing = false;
      _resultMessage = res.message;
      _pendingConfirmation = res.requiresConfirmation ? res : null;
    });

    if (res.handled && !res.requiresConfirmation) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmPending() async {
    final pending = _pendingConfirmation;
    if (pending?.onConfirm == null) return;
    setState(() {
      _processing = true;
    });
    final res = await pending!.onConfirm!();
    if (!mounted) return;
    setState(() {
      _processing = false;
      _pendingConfirmation = null;
      _resultMessage = res.message;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelPending() async {
    final pending = _pendingConfirmation;
    if (pending?.onCancel == null) {
      setState(() => _pendingConfirmation = null);
      return;
    }
    final res = await pending!.onCancel!();
    if (!mounted) return;
    setState(() {
      _pendingConfirmation = null;
      _resultMessage = res.message;
    });
  }

  String _pickBestTranscript() {
    final finalText = _finalText.trim();
    if (finalText.isNotEmpty) return finalText;
    final partial = _partial.trim();
    if (partial.isNotEmpty) return partial;
    return _lastWords.trim();
  }

  @override
  void dispose() {
    _autoProcessTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint =
        'Exemplos:\n'
        '• “agenda treino amanhã às 7 até 8”\n'
        '• “coloca arroz, leite e ovos na lista”\n'
        '• “adiciona lavar banheiro nas tarefas da casa”\n'
        '• “gastei 20 reais de gasolina no débito”';

    final title = _listening
        ? 'Ouvindo…'
        : _processing
        ? 'Processando…'
        : 'Assistente de voz';

    final heardText = _pickBestTranscript();
    final contentText = heardText.isNotEmpty ? heardText : hint;

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
                    ? (_listening
                          ? 'pt-BR • pode falar normalmente'
                          : 'pt-BR • toque para tentar de novo')
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
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _processing
                        ? null
                        : (_listening
                              ? () => _stopAndHandle()
                              : () => _start()),
                    icon: Icon(_listening ? Icons.stop : Icons.refresh),
                    label: Text(_listening ? 'Parar agora' : 'Tentar de novo'),
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
