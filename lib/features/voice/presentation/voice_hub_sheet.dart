// ============================================================================
// FILE: lib/features/voice/presentation/voice_hub_sheet.dart
//
// O que faz:
// - abre o assistente de voz do app
// - começa a ouvir e processa sozinho quando o usuário para de falar
// - mostra confirmação quando o comando precisa de confirmação
// - agora permite editar o comando no ato e reinterpretar sem falar de novo
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
  final TextEditingController _editController = TextEditingController();

  bool _available = false;
  bool _listening = false;
  bool _processing = false;
  bool _processedThisCycle = false;

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
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    final done = status == 'done' || status == 'notListening';
    if (done && _listening && !_processing && !_processedThisCycle) {
      _stopAndHandle(fromStatus: true);
    }
  }

  Future<void> _start() async {
    if (!_available) {
      setState(() {
        _resultMessage =
            'Microfone indisponível.\nVeja a permissão e tente de novo.';
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
      _editController.clear();
    });

    await _speech.listen(
      localeId: 'pt_BR',
      listenMode: ListenMode.dictation,
      partialResults: true,
      listenOptions: SpeechListenOptions(cancelOnError: true),
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(seconds: 20),
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
        _resultMessage = 'Não consegui pegar sua fala.\nTente de novo.';
      });
      return;
    }

    await _handleTranscript(transcript);
  }

  Future<void> _handleTranscript(String transcript) async {
    final res = await widget.router.handle(transcript);
    if (!mounted) return;
    setState(() {
      _resultMessage = res.message;
      _pendingConfirmation = res.requiresConfirmation ? res : null;
      _editController.text = res.editableTranscript?.trim().isNotEmpty == true
          ? res.editableTranscript!.trim()
          : transcript.trim();
      _editController.selection = TextSelection.fromPosition(
        TextPosition(offset: _editController.text.length),
      );
    });

    if (res.handled && !res.requiresConfirmation) {
      await Future.delayed(const Duration(milliseconds: 850));
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
    await Future.delayed(const Duration(milliseconds: 850));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reprocessEdited() async {
    final edited = _editController.text.trim();
    if (edited.isEmpty) return;
    setState(() {
      _processing = true;
      _pendingConfirmation = null;
    });
    await _handleTranscript(edited);
    if (!mounted) return;
    setState(() {
      _processing = false;
    });
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
    _speech.stop();
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint =
        'Exemplos:\n'
        '• “agenda treino amanhã às 7 até 8”\n'
        '• “coloca arroz, leite e ovos na lista”\n'
        '• “adiciona lavar banheiro nos afazeres”\n'
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
                    ? 'pt-BR • toque para tentar de novo'
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
                      TextField(
                        controller: _editController,
                        minLines: 1,
                        maxLines: 3,
                        enabled: !_processing,
                        decoration: const InputDecoration(
                          labelText: 'Ajuste o comando se quiser',
                          hintText:
                              'Ex.: adicionar banana, uva e pera na lista',
                        ),
                      ),
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _processing ? null : _reprocessEdited,
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Editar e reinterpretar'),
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
                  child: FilledButton.icon(
                    onPressed: _listening
                        ? () => _stopAndHandle()
                        : (_processing ? null : _start),
                    icon: Icon(_listening ? Icons.stop : Icons.refresh_rounded),
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
