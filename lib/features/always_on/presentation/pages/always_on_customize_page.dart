// ============================================================================
// FILE: lib/features/always_on/presentation/pages/always_on_customize_page.dart
//
// O que este arquivo faz:
// - Permite personalizar o Sempre Ligado
// - Liga e desliga interesses, temas livres e tickers acompanhados
// - Salva tudo localmente para o feed se moldar ao usuário
// - Deixa a linguagem mais direta, para o usuário entender que está ensinando
//   o radar sobre o que realmente vale seu tempo
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/always_on/data/always_on_presets.dart';
import 'package:vida_app/features/always_on/domain/always_on_models.dart';

class AlwaysOnCustomizePage extends StatefulWidget {
  const AlwaysOnCustomizePage({super.key, required this.initialSettings});

  final AlwaysOnSettings initialSettings;

  @override
  State<AlwaysOnCustomizePage> createState() => _AlwaysOnCustomizePageState();
}

class _AlwaysOnCustomizePageState extends State<AlwaysOnCustomizePage> {
  late final Set<String> _activePresetIds;
  late final List<String> _customTopics;
  late final List<String> _trackedTickers;

  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _tickerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activePresetIds = widget.initialSettings.activePresetIds.toSet();
    _customTopics = List<String>.from(widget.initialSettings.customTopics);
    _trackedTickers = List<String>.from(widget.initialSettings.trackedTickers);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _tickerController.dispose();
    super.dispose();
  }

  void _togglePreset(String id, bool enabled) {
    setState(() {
      if (enabled) {
        _activePresetIds.add(id);
      } else {
        _activePresetIds.remove(id);
      }
    });
  }

  void _addTopic() {
    final value = _topicController.text.trim();
    if (value.isEmpty) return;
    if (_customTopics.any(
      (item) => item.toLowerCase() == value.toLowerCase(),
    )) {
      _topicController.clear();
      return;
    }

    setState(() {
      _customTopics.add(value);
      _topicController.clear();
    });
  }

  void _addTicker() {
    final value = _tickerController.text.trim().toUpperCase();
    if (value.isEmpty) return;
    if (_trackedTickers.contains(value)) {
      _tickerController.clear();
      return;
    }

    setState(() {
      _trackedTickers.add(value);
      _tickerController.clear();
    });
  }

  void _save() {
    final settings = AlwaysOnSettings(
      activePresetIds: _activePresetIds.toList(),
      customTopics: _customTopics,
      trackedTickers: _trackedTickers,
    );

    Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ajustar radar'),
        actions: [TextButton(onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Text(
              'Escolha só o que realmente merece espaço no seu tempo. Quanto mais claro você for aqui, menos conteúdo genérico o radar vai te mostrar.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Interesses principais',
            subtitle:
                'Esses blocos dizem quais temas o radar deve priorizar para você.',
            child: Column(
              children: AlwaysOnPresets.all.map((preset) {
                final enabled = _activePresetIds.contains(preset.id);

                return SwitchListTile(
                  value: enabled,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF22C55E),
                  title: Text(
                    preset.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    preset.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  secondary: Icon(preset.icon, color: Colors.white),
                  onChanged: (value) => _togglePreset(preset.id, value),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Temas livres',
            subtitle:
                'Assuntos específicos que você quer ver do seu jeito. Ex.: OpenAI, Flamengo, Enem, produtividade.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topicController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Adicionar tema'),
                        onSubmitted: (_) => _addTopic(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _addTopic,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                      child: const Text('Adicionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _customTopics.map((topic) {
                    return _RemovableChip(
                      label: topic,
                      onRemove: () {
                        setState(() => _customTopics.remove(topic));
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Tickers observados',
            subtitle:
                'Esses códigos entram como radar extra. Ex.: PETR4, VALE3, IVVB11.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tickerController,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.characters,
                        decoration: _inputDecoration('Adicionar ticker'),
                        onSubmitted: (_) => _addTicker(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _addTicker,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                      child: const Text('Adicionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _trackedTickers.map((ticker) {
                    return _RemovableChip(
                      label: ticker,
                      onRemove: () {
                        setState(() => _trackedTickers.remove(ticker));
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF10182B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF17233D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
