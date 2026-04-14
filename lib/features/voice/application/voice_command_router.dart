// ============================================================================
// FILE: lib/features/voice/application/voice_command_router.dart
//
// O que faz:
// - entende comandos por voz para compras, agenda, tarefas da casa e finanças
// - melhora a limpeza da frase antes de interpretar o comando
// - reduz erros comuns de fala natural, conectivos soltos e palavras sobrando
// - deixa o fluxo compatível com o store atual do app, sem depender de internet
//
// Melhorias desta versão:
// - agenda entende melhor horários humanos como “3 da madrugada” e “10 da manhã”
// - ativa repetição por voz com frases como “todos os dias” e “segunda a sexta”
// - limpa melhor os títulos da timeline, da lista de compras e das tarefas da casa
// - separa melhor itens falados juntos na lista de compras, como “banana maçã e uva”
// ============================================================================

import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/finance/data/local/finance_seed_data.dart';
import 'package:vida_app/features/finance/data/models/finance_category.dart';
import 'package:vida_app/features/finance/data/models/finance_entry_type.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction_source.dart';
import 'package:vida_app/features/finance/presentation/stores/finance_store.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

class VoiceCommandResult {
  const VoiceCommandResult({
    required this.message,
    this.handled = true,
    this.requiresConfirmation = false,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
  });

  final String message;
  final bool handled;
  final bool requiresConfirmation;
  final String? confirmLabel;
  final String? cancelLabel;
  final Future<VoiceCommandResult> Function()? onConfirm;
  final Future<VoiceCommandResult> Function()? onCancel;
}

class VoiceCommandRouter {
  VoiceCommandRouter({
    required this.shopping,
    required this.timeline,
    this.homeTasks,
    this.finance,
  });

  final ShoppingListStore shopping;
  final TimelineStore timeline;
  final HomeTasksStore? homeTasks;
  FinanceStore? finance;

  Future<FinanceStore> _financeStore() async {
    final store = finance ?? FinanceStore();
    finance ??= store;
    if (!store.hasLoaded && !store.isLoading) {
      await store.load();
    }
    return store;
  }

  Future<VoiceCommandResult> handle(String transcript) async {
    final original = _stripWakeWords(transcript).trim();
    if (original.isEmpty) {
      return const VoiceCommandResult(
        message: 'Não entendi. Tente de novo.',
        handled: false,
      );
    }

    final normalized = _normalize(original);

    final financeRemove = await _tryFinanceRemove(original, normalized);
    if (financeRemove != null) return financeRemove;

    final financeUpdate = await _tryFinanceUpdate(original, normalized);
    if (financeUpdate != null) return financeUpdate;

    final shoppingResult = await _tryShoppingAdd(original, normalized);
    if (shoppingResult != null) return shoppingResult;

    final homeTaskResult = await _tryHomeTaskAdd(original, normalized);
    if (homeTaskResult != null) return homeTaskResult;

    final eventResult = await _tryEventAdd(original, normalized);
    if (eventResult != null) return eventResult;

    final financeCreate = await _tryFinanceCreate(original, normalized);
    if (financeCreate != null) return financeCreate;

    return const VoiceCommandResult(
      message:
          'Ainda não entendi esse comando. Tente compras, agenda, tarefas da casa ou finanças.',
      handled: false,
    );
  }

  Future<VoiceCommandResult?> _tryShoppingAdd(
    String original,
    String normalized,
  ) async {
    if (!_looksLikeShoppingAdd(normalized)) return null;

    final items = _sanitizeShoppingItems(_extractShoppingItems(original));
    if (items.isEmpty) {
      return const VoiceCommandResult(
        message: 'Fale os itens depois de “coloca na lista…”.',
        handled: false,
      );
    }

    final shouldConfirm =
        items.length > 1 ||
        items.any((item) => _shoppingItemConfidence(item) < 0.75);
    if (shouldConfirm) {
      final preview = _joinHumanList(items);
      return VoiceCommandResult(
        message: 'Entendi estes itens: $preview. Confirmar?',
        handled: false,
        requiresConfirmation: true,
        confirmLabel: 'Adicionar',
        cancelLabel: 'Cancelar',
        onConfirm: () async {
          await shopping.addMany(items);
          return VoiceCommandResult(
            message: items.length == 1
                ? 'Adicionei ${items.first} na lista.'
                : 'Adicionei ${items.length} itens na lista.',
          );
        },
        onCancel: () async =>
            const VoiceCommandResult(message: 'Ok, não adicionei nada.'),
      );
    }

    await shopping.addMany(items);
    if (items.length == 1) {
      return VoiceCommandResult(message: 'Adicionei ${items.first} na lista.');
    }

    return VoiceCommandResult(
      message: 'Adicionei ${items.length} itens na lista.',
    );
  }

  Future<VoiceCommandResult?> _tryHomeTaskAdd(
    String original,
    String normalized,
  ) async {
    if (homeTasks == null) return null;
    if (!_looksLikeHomeTask(normalized)) return null;

    final title = _extractHomeTaskTitle(original);
    if (title.isEmpty) {
      return const VoiceCommandResult(
        message:
            'Para tarefas da casa, fale o que você quer adicionar. Ex.: “adiciona lavar banheiro nas tarefas da casa”.',
        handled: false,
      );
    }

    final taskConfidence = _taskTitleConfidence(title);
    final taskText = _normalize(title);
    final addTask = () async {
      await homeTasks!.add(
        title: title,
        effort: _homeTaskEffortFromText(taskText),
        category: _homeTaskCategoryFromText(taskText),
        area: _homeTaskAreaFromText(taskText),
      );
      return VoiceCommandResult(
        message: 'Adicionei "$title" nas tarefas da casa.',
      );
    };

    if (taskConfidence < 0.75) {
      return VoiceCommandResult(
        message: 'Entendi esta tarefa: "$title". Confirmar?',
        handled: false,
        requiresConfirmation: true,
        confirmLabel: 'Adicionar',
        cancelLabel: 'Cancelar',
        onConfirm: addTask,
        onCancel: () async =>
            const VoiceCommandResult(message: 'Ok, não adicionei nada.'),
      );
    }

    return await addTask();
  }

  Future<VoiceCommandResult?> _tryEventAdd(
    String original,
    String normalized,
  ) async {
    if (!_looksLikeEvent(normalized)) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tentativeDate = _extractDate(normalized);
    final repeat = _extractRepeatRule(
      normalized,
      referenceDate: tentativeDate ?? today,
    );
    final date = tentativeDate ?? (repeat != null ? today : null);

    if (date == null) {
      return const VoiceCommandResult(
        message:
            'Para agendar, fale também o dia. Ex.: “agenda treino amanhã às 7”.',
        handled: false,
      );
    }

    final timeRange = _extractTimeRange(normalized);
    if (timeRange == null) {
      return const VoiceCommandResult(
        message:
            'Para agendar, fale também o horário. Ex.: “agenda treino amanhã às 7” ou “das 14 às 16”.',
        handled: false,
      );
    }

    final title = _extractEventTitle(original);
    if (title.isEmpty) {
      return const VoiceCommandResult(
        message:
            'Fale também o nome do compromisso. Ex.: “agenda dentista amanhã às 15”.',
        handled: false,
      );
    }
    final eventConfidence = _eventTitleConfidence(title);

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      timeRange.startHour,
      timeRange.startMinute,
    );

    var end = DateTime(
      date.year,
      date.month,
      date.day,
      timeRange.endHour,
      timeRange.endMinute,
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    final event = TimelineBlock(
      id: 'voice_${DateTime.now().microsecondsSinceEpoch}',
      type: _timelineTypeFromText(_normalize(title)),
      title: title,
      start: start,
      end: end,
      notes: 'Criado por voz',
      reminderMinutes: 10,
      repeatType: repeat?.type ?? TimelineRepeatType.none,
      repeatWeekdays: repeat?.weekdays ?? const <int>[],
    );

    if (timeline.hasConflict(event)) {
      return const VoiceCommandResult(
        message:
            'Esse horário bate com outro compromisso. Ajuste a fala e tente de novo.',
        handled: false,
      );
    }

    final repeatText = repeat == null ? '' : ' ${repeat.confirmationText}';
    final confirmText = eventConfidence < 0.80
        ? 'Entendi este evento:\nTítulo: $title\nData: ${_formatDate(date)}\nInício: ${_formatTime(start)}\nFim: ${_formatTime(end)}.$repeatText\n\nConfirmar?'
        : 'Entendi: evento "$title" em ${_formatDate(date)} das ${_formatTime(start)} às ${_formatTime(end)}.$repeatText Confirmar?';
    return VoiceCommandResult(
      message: confirmText,
      handled: false,
      requiresConfirmation: true,
      confirmLabel: 'Criar',
      cancelLabel: 'Cancelar',
      onConfirm: () async {
        await timeline.add(event);
        final repeatDone = repeat == null ? '' : ' ${repeat.confirmationText}';
        return VoiceCommandResult(
          message:
              'Evento "$title" criado para ${_formatDate(date)} às ${_formatTime(start)}.$repeatDone',
        );
      },
      onCancel: () async =>
          const VoiceCommandResult(message: 'Ok, não criei o evento.'),
    );
  }

  Future<VoiceCommandResult?> _tryFinanceCreate(
    String original,
    String normalized,
  ) async {
    if (!_looksLikeFinance(normalized)) return null;

    final amount = _extractAmount(original);
    if (amount == null || amount <= 0) {
      return const VoiceCommandResult(
        message:
            'Para finanças, fale também o valor. Ex.: “gastei 20 reais de gasolina no débito”.',
        handled: false,
      );
    }

    final isIncome = _looksLikeIncome(normalized);
    final entryType = _entryTypeFromText(normalized, isIncome: isIncome);
    final category = _categoryFromText(normalized, isIncome: isIncome);
    final date = _extractDate(normalized) ?? DateTime.now();
    final title = _buildFinanceTitle(
      original,
      normalized,
      category,
      isIncome: isIncome,
    );

    final summary = _financeSummary(
      title: title,
      amount: amount,
      category: category,
      entryType: entryType,
      isIncome: isIncome,
      date: date,
    );

    return VoiceCommandResult(
      message: 'Entendi: $summary. Confirmar?',
      handled: false,
      requiresConfirmation: true,
      confirmLabel: 'Confirmar',
      cancelLabel: 'Cancelar',
      onConfirm: () async {
        final store = await _financeStore();
        final tx = FinanceTransaction(
          id: 'tx_voice_${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          amount: amount,
          date: date,
          category: category,
          entryType: entryType,
          source: FinanceTransactionSource.manual,
          isIncome: isIncome,
          note: 'Lançado por voz: $original',
        );
        await store.addTransaction(tx);
        return VoiceCommandResult(
          message: isIncome
              ? 'Entrada lançada com sucesso.'
              : 'Gasto lançado com sucesso.',
        );
      },
      onCancel: () async =>
          const VoiceCommandResult(message: 'Ok, não lancei nada.'),
    );
  }

  Future<VoiceCommandResult?> _tryFinanceUpdate(
    String original,
    String normalized,
  ) async {
    final mentionsLast =
        normalized.contains('ultimo') || normalized.contains('ultim');
    final wantsChange =
        normalized.contains('corrig') ||
        normalized.contains('alter') ||
        normalized.contains('mud') ||
        normalized.contains('edita');

    if (!mentionsLast || !wantsChange) return null;

    final store = await _financeStore();
    if (store.transactions.isEmpty) {
      return const VoiceCommandResult(
        message: 'Ainda não há lançamentos para corrigir.',
        handled: false,
      );
    }

    final items = List<FinanceTransaction>.from(store.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final last = items.first;

    final newAmount = _extractAmount(original);
    final newEntryType = _entryTypeFromTextOrNull(
      normalized,
      isIncome: last.isIncome,
    );
    final newCategory = _categoryFromTextOrNull(
      normalized,
      isIncome: last.isIncome,
    );
    final newTitle = _buildUpdateTitle(original, normalized, last);

    if (newAmount == null &&
        newEntryType == null &&
        newCategory == null &&
        newTitle == null) {
      return const VoiceCommandResult(
        message:
            'Para corrigir o último lançamento, diga o que quer mudar. Ex.: “corrige o último gasto para 25” ou “o último foi no crédito”.',
        handled: false,
      );
    }

    final updated = last.copyWith(
      amount: newAmount ?? last.amount,
      entryType: newEntryType ?? last.entryType,
      category: newCategory ?? last.category,
      title: newTitle ?? last.title,
      note: 'Atualizado por voz: $original',
    );

    final summary = _financeSummary(
      title: updated.title,
      amount: updated.amount,
      category: updated.category,
      entryType: updated.entryType,
      isIncome: updated.isIncome,
      date: updated.date,
    );

    return VoiceCommandResult(
      message:
          'Entendi: atualizar o último lançamento para $summary. Confirmar?',
      handled: false,
      requiresConfirmation: true,
      confirmLabel: 'Atualizar',
      cancelLabel: 'Cancelar',
      onConfirm: () async {
        await store.updateTransaction(updated);
        return const VoiceCommandResult(
          message: 'Último lançamento atualizado.',
        );
      },
      onCancel: () async =>
          const VoiceCommandResult(message: 'Ok, deixei como estava.'),
    );
  }

  Future<VoiceCommandResult?> _tryFinanceRemove(
    String original,
    String normalized,
  ) async {
    if (!((normalized.contains('remove') ||
                normalized.contains('apaga') ||
                normalized.contains('exclui')) &&
            (normalized.contains('ultimo') || normalized.contains('ultim'))) &&
        !((normalized.contains('remove') ||
                normalized.contains('apaga') ||
                normalized.contains('exclui')) &&
            normalized.contains('lancamento'))) {
      return null;
    }

    final store = await _financeStore();
    if (store.transactions.isEmpty) {
      return const VoiceCommandResult(
        message: 'Ainda não há lançamentos para remover.',
        handled: false,
      );
    }

    final items = List<FinanceTransaction>.from(store.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final last = items.first;

    return VoiceCommandResult(
      message:
          'Entendi: remover o último lançamento "${last.title}" no valor de ${_formatMoney(last.amount)}. Confirmar?',
      handled: false,
      requiresConfirmation: true,
      confirmLabel: 'Remover',
      cancelLabel: 'Cancelar',
      onConfirm: () async {
        await store.removeTransaction(last.id);
        return const VoiceCommandResult(message: 'Último lançamento removido.');
      },
      onCancel: () async =>
          const VoiceCommandResult(message: 'Ok, não removi nada.'),
    );
  }

  bool _containsAny(String text, Iterable<String> terms) {
    for (final term in terms) {
      if (text.contains(term)) return true;
    }
    return false;
  }

  bool _looksLikeAddVerb(String text) {
    return _containsAny(text, const [
      'coloca',
      'colocar',
      'adiciona',
      'adicionar',
      'adicione',
      'adione',
      'bota',
      'botar',
      'poe',
      'põe',
      'ponha',
      'anota',
      'anotar',
      'inclui',
      'incluir',
    ]);
  }

  String _cleanLooseCommandWords(String text) {
    var value = text;
    value = value.replaceAll(
      RegExp(
        r'\b(r|rs|reais?|real|conto|contos|horas?)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    value = value.replaceAll(
      RegExp(
        r'\b(adiciona|adicionar|adicione|adione|coloca|colocar|bota|botar|anota|anotar|agenda|agendar|marca|marcar|evento|compromisso|lista|compras?|afazeres?|tarefas?)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    value = value.replaceAll(
      RegExp(
        r'\b(na|no|nas|nos|pra|para|pro|de|da|do|em|as|às|a|e)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  bool _looksLikeShoppingAdd(String text) {
    final hasVerb = _looksLikeAddVerb(text);
    final hasContext =
        text.contains('lista') ||
        text.contains('compra') ||
        text.contains('compras') ||
        text.contains('mercado');
    return hasVerb && hasContext;
  }

  List<String> _extractShoppingItems(String original) {
    var text = original.trim();

    text = text.replaceFirst(
      RegExp(
        r'^\s*(coloca|colocar|adiciona|adicionar|adicione|adione|bota|botar|poe|põe|ponha|anota|anotar|inclui|incluir)\s+',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'\b(a\s+)?lista\s+de\s+compras?\b|\blista\b|\bcompras?\b|\bmercado\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'\b(na|no|pra|para|pro|de|da|do)\b', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'\s+e\s+mais\s+', caseSensitive: false),
      ',',
    );
    text = text.replaceAll(RegExp(r'\s+mais\s+', caseSensitive: false), ',');
    text = text.replaceAll(';', ',');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    final parts = <String>[];
    for (final segment in text.split(',')) {
      parts.addAll(_expandShoppingSegment(segment));
    }

    final cleaned = parts
        .map(_sanitizeShoppingItem)
        .where((e) => e.isNotEmpty)
        .toList();

    final seen = <String>{};
    final unique = <String>[];
    for (final item in cleaned) {
      final key = _normalize(item);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      unique.add(item);
    }
    return unique;
  }

  Iterable<String> _expandShoppingSegment(String raw) sync* {
    final text = raw.trim();
    if (text.isEmpty) return;

    final normalized = _normalize(text);
    final byConnector = normalized.split(RegExp(r'\s+(?:e|mais|junto com)\s+'));
    if (byConnector.length > 1) {
      for (final piece in byConnector) {
        yield* _expandShoppingSegment(piece);
      }
      return;
    }

    final words = normalized
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    const joinerWords = {
      'de',
      'da',
      'do',
      'das',
      'dos',
      'com',
      'sem',
      'integral',
      'light',
      'zero',
      'po',
      'poo',
      'pó',
      'natural',
      'desnatado',
      'limpeza',
      'louca',
      'louça',
      'banho',
      'rosto',
      'cabelo',
      'dente',
      'papel',
      'sanitario',
      'sanitário',
      'em',
    };

    const descriptorWords = {
      'prata',
      'nanica',
      'verde',
      'gala',
      'fuji',
      'grande',
      'pequena',
      'pequeno',
      'maduro',
      'madura',
      'fresco',
      'fresca',
      'moida',
      'moída',
      'integral',
      'desnatado',
      'desnatada',
      'semidesnatado',
      'semidesnatada',
      'branco',
      'branca',
      'preto',
      'preta',
    };

    const standaloneFoodWords = {
      'banana',
      'maca',
      'maçã',
      'uva',
      'pera',
      'manga',
      'abacaxi',
      'laranja',
      'limao',
      'limão',
      'morango',
      'pao',
      'pão',
      'leite',
      'ovo',
      'ovos',
      'cafe',
      'café',
      'arroz',
      'feijao',
      'feijão',
      'queijo',
      'presunto',
      'frango',
      'carne',
      'peixe',
      'iogurte',
      'agua',
      'água',
      'suco',
      'sabao',
      'sabão',
      'detergente',
      'amaciante',
      'papel',
      'shampoo',
      'condicionador',
    };

    final hasQuantity = words.any((w) => RegExp(r'^\d+[a-z]*$').hasMatch(w));
    final shouldSplitIntoSingles =
        words.length >= 2 &&
        words.length <= 6 &&
        !hasQuantity &&
        !words.any(joinerWords.contains);

    if (shouldSplitIntoSingles) {
      final items = <String>[];
      var current = <String>[];

      bool isStandaloneNoun(String word) {
        return standaloneFoodWords.contains(word);
      }

      for (var i = 0; i < words.length; i++) {
        final word = words[i];
        final next = i + 1 < words.length ? words[i + 1] : null;

        if (current.isEmpty) {
          current.add(word);
          continue;
        }

        final currentBase = current.first;
        final currentIsStandalone = isStandaloneNoun(currentBase);
        final nextIsDescriptor = next != null && descriptorWords.contains(next);

        if (descriptorWords.contains(word) ||
            joinerWords.contains(word) ||
            (currentIsStandalone && nextIsDescriptor)) {
          current.add(word);
          continue;
        }

        final wordIsStandalone = isStandaloneNoun(word);
        if (currentIsStandalone && wordIsStandalone) {
          items.add(current.join(' '));
          current = [word];
          continue;
        }

        current.add(word);
      }

      if (current.isNotEmpty) {
        items.add(current.join(' '));
      }

      if (items.length > 1) {
        for (final item in items) {
          yield item;
        }
        return;
      }
    }

    yield normalized;
  }

  String _sanitizeShoppingItem(String raw) {
    var text = raw.trim();
    text = text.replaceAll(
      RegExp(
        r'^(coloca|colocar|adiciona|adicionar|adicione|adione|bota|botar|poe|põe|ponha|anota|anotar|inclui|incluir)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(lista\s+de\s+compras?|lista|compras?|mercado)\b',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'^(na|no|de|do|da|pra|para|pro|o|a|os|as|um|uma|e)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'\s+(na|no|de|do|da|pra|para|pro|o|a|os|as|um|uma|e)$',
        caseSensitive: false,
      ),
      '',
    );
    text = _stripTrailingGenericGarbage(text);
    text = _repairFreeText(text, domain: _FreeTextDomain.shopping);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    final lower = _normalize(text);
    if (text.isEmpty) return '';
    if (text.length == 1 && {'a', 'e', 'o'}.contains(lower)) return '';
    if ({
      'de',
      'do',
      'da',
      'na',
      'no',
      'pra',
      'para',
      'lista',
      'compra',
      'compras',
    }.contains(lower)) {
      return '';
    }

    return _capitalize(text);
  }

  bool _looksLikeHomeTask(String text) {
    return text.contains('tarefa da casa') ||
        text.contains('tarefas da casa') ||
        text.contains('lista de afazeres') ||
        text.contains('lista de tarefas') ||
        text.contains('afazer') ||
        text.contains('afazeres') ||
        text.contains('a fazer') ||
        text.contains('em casa') ||
        text.contains('lavar') ||
        text.contains('limpar') ||
        text.contains('organizar') ||
        text.contains('arrumar') ||
        text.contains('consertar') ||
        text.contains('varrer') ||
        text.contains('passar pano');
  }

  String _extractHomeTaskTitle(String original) {
    var text = original.trim();
    text = text.replaceFirst(
      RegExp(
        r'^\s*(adiciona|adicionar|adicione|adione|coloca|colocar|bota|botar|anota|anotar|inclui|incluir)\s+',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'\b(a\s+)?lista\s+de\s+(afazeres|tarefas?)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(nas|na|nos|no|pra|para|em)\s+(tarefas?\s+da\s+casa|afazeres?\s+da\s+casa|lista\s+de\s+afazeres|lista\s+de\s+tarefas|casa)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(tarefas?\s+da\s+casa|afazeres?\s+da\s+casa|lista\s+de\s+afazeres|lista\s+de\s+tarefas)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'^(eu\s+quero\s+|quero\s+|preciso\s+|pode\s+|por\s+favor\s+)',
        caseSensitive: false,
      ),
      '',
    );

    text = _cleanLooseCommandWords(text);
    text = _sanitizeTaskTitle(text);
    if (text.isEmpty) return '';
    return text;
  }

  HomeTaskEffort _homeTaskEffortFromText(String text) {
    if (text.contains('consert') ||
        text.contains('reform') ||
        text.contains('pint') ||
        text.contains('faxina')) {
      return HomeTaskEffort.major;
    }
    return HomeTaskEffort.quick;
  }

  HomeTaskCategory _homeTaskCategoryFromText(String text) {
    if (text.contains('consert') ||
        text.contains('trocar') ||
        text.contains('repar')) {
      return HomeTaskCategory.maintenance;
    }
    if (text.contains('organ') || text.contains('arrum')) {
      return HomeTaskCategory.organization;
    }
    return HomeTaskCategory.cleaning;
  }

  HomeTaskArea _homeTaskAreaFromText(String text) {
    if (text.contains('cozinha')) return HomeTaskArea.kitchen;
    if (text.contains('banheiro')) return HomeTaskArea.bathroom;
    if (text.contains('quarto')) return HomeTaskArea.bedroom;
    if (text.contains('sala')) return HomeTaskArea.livingRoom;
    if (text.contains('lavanderia')) return HomeTaskArea.laundry;
    if (text.contains('quintal') ||
        text.contains('garagem') ||
        text.contains('jardim')) {
      return HomeTaskArea.outdoor;
    }
    if (text.contains('casa')) return HomeTaskArea.wholeHouse;
    return HomeTaskArea.other;
  }

  bool _looksLikeEvent(String text) {
    final hasSchedulingVerb =
        text.contains('agenda') ||
        text.contains('agendar') ||
        text.contains('marca ') ||
        text.contains('marcar') ||
        text.contains('evento') ||
        text.contains('compromisso') ||
        text.contains('programa') ||
        text.contains('programar') ||
        text.contains('adiciona') ||
        text.contains('adicionar');
    final hasDate = _extractDate(text) != null;
    final hasTime = _extractTimeRange(text) != null;
    final hasRepeat =
        _extractRepeatRule(text, referenceDate: DateTime.now()) != null;
    final hasTypicalTitle =
        text.contains('treino') ||
        text.contains('reuniao') ||
        text.contains('reunião') ||
        text.contains('consulta') ||
        text.contains('dentista') ||
        text.contains('medico') ||
        text.contains('médico') ||
        text.contains('academia') ||
        text.contains('prova') ||
        text.contains('aula') ||
        text.contains('descanso') ||
        text.contains('sono') ||
        text.contains('trabalho');

    return hasSchedulingVerb ||
        (hasDate && hasTime) ||
        (hasRepeat && hasTime && hasTypicalTitle) ||
        (hasTime && hasTypicalTitle);
  }

  TimelineBlockType _timelineTypeFromText(String text) {
    if (text.contains('treino') || text.contains('academia')) {
      return TimelineBlockType.workout;
    }
    if (text.contains('estudo') ||
        text.contains('aula') ||
        text.contains('prova')) {
      return TimelineBlockType.study;
    }
    if (text.contains('dentista') ||
        text.contains('medico') ||
        text.contains('médico') ||
        text.contains('consulta')) {
      return TimelineBlockType.health;
    }
    if (text.contains('descanso') || text.contains('dormir')) {
      return TimelineBlockType.rest;
    }
    if (text.contains('amigo') ||
        text.contains('familia') ||
        text.contains('família')) {
      return TimelineBlockType.social;
    }
    return TimelineBlockType.event;
  }

  DateTime? _extractDate(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('hoje') || text.contains('de hoje')) return today;
    if (text.contains('depois de amanha') ||
        text.contains('depois de amanhã')) {
      return today.add(const Duration(days: 2));
    }
    if (text.contains('amanha') || text.contains('amanhã')) {
      return today.add(const Duration(days: 1));
    }
    if (text.contains('ontem')) {
      return today.subtract(const Duration(days: 1));
    }

    final slash = RegExp(
      r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b',
    ).firstMatch(text);
    if (slash != null) {
      final day = int.tryParse(slash.group(1)!);
      final month = int.tryParse(slash.group(2)!);
      var year = int.tryParse(slash.group(3) ?? '') ?? now.year;
      if (year < 100) year += 2000;
      if (day != null && month != null) {
        return DateTime(year, month, day);
      }
    }

    final weekdays = <String, int>{
      'segunda': DateTime.monday,
      'terca': DateTime.tuesday,
      'terça': DateTime.tuesday,
      'quarta': DateTime.wednesday,
      'quinta': DateTime.thursday,
      'sexta': DateTime.friday,
      'sabado': DateTime.saturday,
      'sábado': DateTime.saturday,
      'domingo': DateTime.sunday,
    };

    bool asksCurrentWeek(String value) =>
        value.contains('nessa ') ||
        value.contains('nesta ') ||
        value.contains('essa ') ||
        value.contains('esta ');

    for (final entry in weekdays.entries) {
      if (text.contains(entry.key)) {
        final diff = (entry.value - today.weekday + 7) % 7;
        if (diff == 0) return today;
        final days = asksCurrentWeek(text) ? diff : (diff == 0 ? 7 : diff);
        return today.add(Duration(days: days));
      }
    }

    return null;
  }

  _TimeRange? _extractTimeRange(String text) {
    final normalized = _normalizeTimeText(text);
    final timePhrase =
        r'(?:meio dia|meia noite|\d{1,2}(?::\d{1,2})?(?:\s*h(?:oras?)?|\s+horas?)?(?:\s+e\s+meia)?(?:\s+da\s+(?:manha|madrugada|tarde|noite))?)';

    final fullPatterns = [
      RegExp(
        '(?:das?\\s+|de\\s+)?($timePhrase)\\s+(?:ate|as|a)\\s+($timePhrase)',
      ),
      RegExp('\\b($timePhrase)\\s*[-]\\s*($timePhrase)\\b'),
    ];

    for (final pattern in fullPatterns) {
      final full = pattern.firstMatch(normalized);
      if (full == null) continue;
      final start = _parseTimePhrase(full.group(1)!);
      final end = _parseTimePhrase(full.group(2)!);
      if (start != null && end != null) {
        return _TimeRange(
          startHour: start.hour,
          startMinute: start.minute,
          endHour: end.hour,
          endMinute: end.minute,
        );
      }
    }

    final singlePatterns = [
      RegExp('(?:as|a)\\s+($timePhrase)'),
      RegExp('\\b($timePhrase)\\b'),
    ];

    for (final pattern in singlePatterns) {
      final single = pattern.firstMatch(normalized);
      if (single == null) continue;
      final parsed = _parseTimePhrase(single.group(1)!);
      if (parsed != null) {
        final endHour = (parsed.hour + 1) % 24;
        return _TimeRange(
          startHour: parsed.hour,
          startMinute: parsed.minute,
          endHour: endHour,
          endMinute: parsed.minute,
        );
      }
    }

    return null;
  }

  int _parseMinute(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  String _normalizeTimeText(String text) {
    var value = _normalize(text);
    value = value.replaceAll('meio dia', '12:00');
    value = value.replaceAll('meia noite', '00:00');
    value = value.replaceAllMapped(
      RegExp(r'\b(\d{1,2})\s*e\s*meia\b'),
      (m) => '${m.group(1)}:30',
    );
    value = value
        .replaceAll('hrs', 'h')
        .replaceAll('horinha', 'hora')
        .replaceAll('horinhas', 'horas');
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  _ParsedTimePoint? _parseTimePhrase(String raw) {
    final text = _normalizeTimeText(raw);

    if (text.contains('12:00')) {
      return const _ParsedTimePoint(hour: 12, minute: 0);
    }
    if (text.contains('00:00')) {
      return const _ParsedTimePoint(hour: 0, minute: 0);
    }

    int? hour;
    int minute = 0;

    final hhmm = RegExp(r'\b(\d{1,2}):(\d{1,2})\b').firstMatch(text);
    if (hhmm != null) {
      hour = int.tryParse(hhmm.group(1)!);
      minute = int.tryParse(hhmm.group(2)!) ?? 0;
    } else {
      final hWithMinutes = RegExp(
        r'\b(\d{1,2})\s*h\s*(\d{1,2})\b',
      ).firstMatch(text);
      if (hWithMinutes != null) {
        hour = int.tryParse(hWithMinutes.group(1)!);
        minute = int.tryParse(hWithMinutes.group(2)!) ?? 0;
      } else {
        final hOnly = RegExp(r'\b(\d{1,2})\b').firstMatch(text);
        if (hOnly != null) {
          hour = int.tryParse(hOnly.group(1)!);
          if (text.contains('e meia')) minute = 30;
        }
      }
    }

    if (hour == null) return null;

    if (text.contains('madrugada')) {
      if (hour == 12) hour = 0;
    } else if (text.contains('manha')) {
      if (hour == 12) hour = 0;
    } else if (text.contains('tarde')) {
      if (hour < 12) hour += 12;
    } else if (text.contains('noite')) {
      if (hour < 12) hour += 12;
      if (hour == 24) hour = 0;
    }

    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);
    return _ParsedTimePoint(hour: hour, minute: minute);
  }

  _RepeatRule? _extractRepeatRule(
    String text, {
    required DateTime referenceDate,
  }) {
    final normalized = _normalize(text);

    if (normalized.contains('todos os dias') ||
        normalized.contains('todo dia') ||
        normalized.contains('todo santo dia') ||
        normalized.contains('todos dia') ||
        normalized.contains('diariamente') ||
        normalized.contains('repetir diariamente') ||
        normalized.contains('repete diariamente') ||
        normalized.contains('repetir todo dia') ||
        normalized.contains('repete todo dia') ||
        normalized.contains('repita diariamente') ||
        normalized.contains('repetir todos os dias') ||
        normalized.contains('repete todos os dias')) {
      return const _RepeatRule(
        type: TimelineRepeatType.daily,
        confirmationText: 'Vai repetir todos os dias.',
      );
    }

    if (normalized.contains('toda semana') ||
        normalized.contains('todas as semanas') ||
        normalized.contains('semanalmente') ||
        normalized.contains('repetir semanalmente') ||
        normalized.contains('repete semanalmente')) {
      return const _RepeatRule(
        type: TimelineRepeatType.weekly,
        confirmationText: 'Vai repetir toda semana.',
      );
    }

    if (normalized.contains('segunda a sexta') ||
        normalized.contains('segunda ate sexta') ||
        normalized.contains('de segunda a sexta')) {
      return const _RepeatRule(
        type: TimelineRepeatType.customWeekdays,
        weekdays: <int>[
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ],
        confirmationText: 'Vai repetir de segunda a sexta.',
      );
    }

    final weekdayMap = <String, int>{
      'segunda': DateTime.monday,
      'terca': DateTime.tuesday,
      'terça': DateTime.tuesday,
      'quarta': DateTime.wednesday,
      'quinta': DateTime.thursday,
      'sexta': DateTime.friday,
      'sabado': DateTime.saturday,
      'sábado': DateTime.saturday,
      'domingo': DateTime.sunday,
    };

    final weekdays = <int>{};
    for (final entry in weekdayMap.entries) {
      if (normalized.contains('toda ${entry.key}') ||
          normalized.contains('todo ${entry.key}') ||
          normalized.contains('cada ${entry.key}') ||
          normalized.contains('repetir ${entry.key}') ||
          normalized.contains('repete ${entry.key}') ||
          normalized.contains('todo ${entry.key} feira') ||
          normalized.contains('toda ${entry.key} feira')) {
        weekdays.add(entry.value);
      }
    }

    if (weekdays.length == 1) {
      return const _RepeatRule(
        type: TimelineRepeatType.weekly,
        confirmationText: 'Vai repetir toda semana.',
      );
    }

    if (weekdays.length > 1) {
      final ordered = weekdays.toList()..sort();
      return _RepeatRule(
        type: TimelineRepeatType.customWeekdays,
        weekdays: ordered,
        confirmationText: 'Vai repetir em dias da semana definidos.',
      );
    }

    return null;
  }

  String _extractEventTitle(String original) {
    var text = original.trim();

    text = text.replaceAll(
      RegExp(
        r'^(agenda|agendar|marca|marcar|cria\s+evento|criar\s+evento|adiciona\s+evento|adicionar\s+evento|evento|compromisso|programa|programar|adiciona|adicionar)\s+',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'\b(na\s+agenda|no\s+calendario|no\s+calendário|no\s+meu\s+dia|na\s+timeline)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    final cutPatterns = <RegExp>[
      RegExp(
        r'\b(repetir\s+diariamente|repete\s+diariamente|repetir\s+todos\s+os\s+dias|todos\s+os\s+dias|todo\s+dia|todo\s+santo\s+dia|diariamente|toda\s+semana|semanalmente|segunda\s+a\s+sexta|de\s+segunda\s+a\s+sexta|toda\s+segunda|toda\s+terca|toda\s+terça|toda\s+quarta|toda\s+quinta|toda\s+sexta|toda\s+sabado|toda\s+sábado|todo\s+domingo)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(de\s+)?(amanha|amanhã|hoje|ontem|segunda|terca|terça|quarta|quinta|sexta|sabado|sábado|domingo)\b',
        caseSensitive: false,
      ),
      RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b', caseSensitive: false),
      RegExp(
        r'\b(?:das?|de|às?|a\s+partir\s+das?)\s+(?:meio\s+dia|meia\s+noite|\d{1,2}(?::\d{1,2})?(?:\s*h(?:oras?)?|\s+horas?)?(?:\s+e\s+meia)?(?:\s+(?:da\s+)?(?:manha|manhã|madruagada|madrugada|tarde|noite))?)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b\d{1,2}(?::\d{1,2})?(?:\s*h(?:oras?)?|\s+horas?)(?:\s+e\s+meia)?(?:\s+(?:da\s+)?(?:manha|manhã|madruagada|madrugada|tarde|noite))?',
        caseSensitive: false,
      ),
    ];

    int cutIndex = text.length;
    for (final pattern in cutPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.start < cutIndex) {
        cutIndex = match.start;
      }
    }

    if (cutIndex < text.length) {
      text = text.substring(0, cutIndex);
    }

    text = _cleanLooseCommandWords(text);
    text = _sanitizeEventTitle(text);

    if (text.isEmpty) return '';
    return text;
  }

  String _stripTrailingTimeGarbage(String input) {
    var text = input.trim();

    final trailingPatterns = <RegExp>[
      RegExp(
        r'\s+\d{1,2}(?::\d{1,2})?(?:\s*h(?:oras?)?|\s+horas?)?(?:\s+e\s+meia)?(?:\s+(?:da\s+)?(?:manha|manhã|madrugada|madruagada|tarde|noite))?\s*$',
        caseSensitive: false,
      ),
      RegExp(
        r'\s+(?:manha|manhã|madrugada|madruagada|tarde|noite)\s*$',
        caseSensitive: false,
      ),
    ];

    var changed = true;
    while (changed) {
      changed = false;
      for (final pattern in trailingPatterns) {
        final next = text
            .replaceAll(pattern, ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (next != text) {
          text = next;
          changed = true;
        }
      }
    }

    return text;
  }

  String _stripTrailingGenericGarbage(String input) {
    var text = input.trim();
    text = text.replaceAll(
      RegExp(
        r'\b(na|no|nas|nos|para|pra|pro|de|da|do|das|dos|em|as|às|a|e)$',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String _repairFreeText(String input, {required _FreeTextDomain domain}) {
    var text = _normalize(input);
    if (text.isEmpty) return '';

    const explicitFixes = <String, String>{
      'fes': 'festa',
      'feis': 'festa',
      'mansa': 'maca',
      'cafee': 'cafe',
    };
    explicitFixes.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    final tokens = text
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final repaired = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      var token = tokens[i];
      if (domain == _FreeTextDomain.task && i == 0) {
        token = _normalizeTaskVerbToken(token);
      }
      repaired.add(_bestVocabularyMatch(token, domain) ?? token);
    }

    return repaired.join(' ').trim();
  }

  String? _bestVocabularyMatch(String token, _FreeTextDomain domain) {
    if (token.isEmpty) return null;
    final vocabulary = switch (domain) {
      _FreeTextDomain.event => _eventVocabulary,
      _FreeTextDomain.task => _taskVocabulary,
      _FreeTextDomain.shopping => _shoppingVocabulary,
    };

    if (vocabulary.contains(token)) return token;
    if (token.length >= 6) return null;

    String? best;
    var bestDistance = 999;
    for (final candidate in vocabulary) {
      final distance = _levenshtein(token, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    if (best == null) return null;
    final maxAllowed = token.length <= 3 ? 2 : 1;
    return bestDistance <= maxAllowed ? best : null;
  }

  int _levenshtein(String a, String b) {
    final rows = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      rows[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      rows[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        rows[i][j] = [
          rows[i - 1][j] + 1,
          rows[i][j - 1] + 1,
          rows[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return rows[a.length][b.length];
  }

  String _sanitizeEventTitle(String raw) {
    var text = raw.trim();
    text = _stripTrailingTimeGarbage(text);
    text = _stripTrailingGenericGarbage(text);
    text = _repairFreeText(text, domain: _FreeTextDomain.event);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    return _capitalize(text);
  }

  String _sanitizeTaskTitle(String raw) {
    var text = raw.trim();
    text = _stripTrailingGenericGarbage(text);
    text = _repairFreeText(text, domain: _FreeTextDomain.task);
    text = _normalizeTaskVerbStyle(text);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    return _capitalize(text);
  }

  List<String> _sanitizeShoppingItems(List<String> rawItems) {
    final cleaned = rawItems
        .map(_sanitizeShoppingItem)
        .where((e) => e.isNotEmpty)
        .toList();
    final seen = <String>{};
    final unique = <String>[];
    for (final item in cleaned) {
      final key = _normalize(item);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      unique.add(item);
    }
    return unique;
  }

  String _sanitizeFinanceTitle(String raw) {
    var text = raw.trim();
    text = _stripTrailingGenericGarbage(text);
    text = _repairFreeText(text, domain: _FreeTextDomain.shopping);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    return _capitalize(text);
  }

  double _eventTitleConfidence(String title) {
    var score = 1.0;
    final normalized = _normalize(title);
    if (normalized.isEmpty) return 0.0;
    if (normalized.contains(RegExp(r'\d'))) score -= 0.45;
    if (_containsAny(normalized, const [
      'agenda',
      'agendar',
      'evento',
      'compromisso',
      'manha',
      'madrugada',
      'tarde',
      'noite',
      'hoje',
      'amanha',
      'repetir',
    ])) {
      score -= 0.45;
    }
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.any((t) => t.length == 1)) score -= 0.25;
    if (tokens.length == 1) {
      final token = tokens.first;
      if (token.length <= 2) score -= 0.50;
      if (token.length <= 3 && !_eventVocabulary.contains(token)) score -= 0.35;
    }
    return score.clamp(0.0, 1.0);
  }

  double _taskTitleConfidence(String title) {
    var score = 1.0;
    final normalized = _normalize(title);
    if (normalized.isEmpty) return 0.0;
    if (_containsAny(normalized, const [
      'lista',
      'afazeres',
      'tarefas',
      'adicionar',
      'adicione',
      'adione',
    ])) {
      score -= 0.45;
    }
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return 0.0;
    if (tokens.any((t) => t.length == 1)) score -= 0.30;
    return score.clamp(0.0, 1.0);
  }

  double _shoppingItemConfidence(String item) {
    var score = 1.0;
    final normalized = _normalize(item);
    if (normalized.isEmpty) return 0.0;
    if (_containsAny(normalized, const [
      'lista',
      'compras',
      'adicionar',
      'adicione',
      'adione',
    ])) {
      score -= 0.45;
    }
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return 0.0;
    if (tokens.any((t) => t.length == 1)) score -= 0.35;
    if (tokens.length > 4) score -= 0.20;
    return score.clamp(0.0, 1.0);
  }

  String _joinHumanList(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items.first} e ${items.last}';
    return '${items.sublist(0, items.length - 1).join(', ')} e ${items.last}';
  }

  String _normalizeTaskVerbStyle(String text) {
    final tokens = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return text.trim();
    tokens[0] = _normalizeTaskVerbToken(_normalize(tokens[0]));
    return tokens.join(' ');
  }

  String _normalizeTaskVerbToken(String token) {
    const verbMap = <String, String>{
      'conserta': 'consertar',
      'lava': 'lavar',
      'limpa': 'limpar',
      'arruma': 'arrumar',
      'organiza': 'organizar',
      'varre': 'varrer',
      'passa': 'passar',
      'troca': 'trocar',
      'guarda': 'guardar',
      'compra': 'comprar',
      'leva': 'levar',
      'busca': 'buscar',
      'paga': 'pagar',
    };
    return verbMap[token] ?? token;
  }

  static const Set<String> _eventVocabulary = {
    'festa',
    'treino',
    'descanso',
    'reuniao',
    'consulta',
    'dentista',
    'medico',
    'exame',
    'trabalho',
    'estudo',
    'aula',
    'prova',
    'sono',
    'dormir',
    'mercado',
    'almoco',
    'jantar',
    'cafe',
  };

  static const Set<String> _taskVocabulary = {
    'lavar',
    'limpar',
    'organizar',
    'arrumar',
    'consertar',
    'trocar',
    'varrer',
    'passar',
    'guardar',
    'comprar',
    'pagar',
    'levar',
    'buscar',
    'tv',
    'banheiro',
    'quarto',
    'cozinha',
    'sala',
  };

  static const Set<String> _shoppingVocabulary = {
    'banana',
    'maca',
    'uva',
    'pera',
    'manga',
    'abacaxi',
    'laranja',
    'limao',
    'cafe',
    'agua',
    'pao',
    'leite',
    'ovos',
    'ovo',
    'arroz',
    'feijao',
    'queijo',
    'presunto',
    'frango',
    'carne',
    'peixe',
    'iogurte',
    'detergente',
    'sabao',
    'amaciante',
    'shampoo',
    'condicionador',
  };

  bool _looksLikeFinance(String text) {
    final hasMoney = _extractAmount(text) != null;
    final hasFinanceVerb =
        text.contains('gastei') ||
        text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('salario') ||
        text.contains('salário') ||
        text.contains('paguei') ||
        text.contains('comprei') ||
        text.contains('investi') ||
        text.contains('depositei') ||
        text.contains('caiu');
    final hasPaymentContext =
        text.contains('pix') ||
        text.contains('debito') ||
        text.contains('débito') ||
        text.contains('credito') ||
        text.contains('crédito') ||
        text.contains('cartao') ||
        text.contains('cartão') ||
        text.contains('boleto') ||
        text.contains('dinheiro') ||
        text.contains('reais') ||
        text.contains('real') ||
        text.contains('conto') ||
        text.contains('contos');

    return hasMoney &&
        (hasFinanceVerb ||
            hasPaymentContext ||
            _categoryFromTextOrNull(text, isIncome: false) != null ||
            _looksLikeIncome(text));
  }

  bool _looksLikeIncome(String text) {
    return text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('salario') ||
        text.contains('salário') ||
        text.contains('pagamento') ||
        text.contains('entrada') ||
        text.contains('caiu') ||
        text.contains('depositaram') ||
        text.contains('deposito');
  }

  double? _extractAmount(String text) {
    final source = text.toLowerCase();

    final contos = RegExp(
      r'\b(\d+(?:[\.,]\d+)?)\s*contos?\b',
    ).firstMatch(source);
    if (contos != null) {
      final raw = contos.group(1)!;
      final normalized = _normalizeAmountString(raw);
      final value = double.tryParse(normalized);
      if (value != null && value > 0) return value;
    }

    final moneyContext = RegExp(
      r'(?:r\$\s*)?(\d[\d\s\.,]*\d|\d)\s*(reais|real)?',
      caseSensitive: false,
    );

    final matches = moneyContext
        .allMatches(source)
        .map((m) => m.group(1) ?? '')
        .where((m) => m.trim().isNotEmpty)
        .toList();

    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.length.compareTo(a.length));
      for (final raw in matches) {
        final normalized = _normalizeAmountString(raw);
        final value = double.tryParse(normalized);
        if (value != null && value > 0) return value;
      }
    }

    return _extractAmountFromWords(source);
  }

  double? _extractAmountFromWords(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return null;

    final tokens = normalized.split(RegExp(r'\s+'));
    const units = {
      'zero': 0,
      'um': 1,
      'uma': 1,
      'dois': 2,
      'duas': 2,
      'tres': 3,
      'três': 3,
      'quatro': 4,
      'cinco': 5,
      'seis': 6,
      'sete': 7,
      'oito': 8,
      'nove': 9,
      'dez': 10,
      'onze': 11,
      'doze': 12,
      'treze': 13,
      'catorze': 14,
      'quatorze': 14,
      'quinze': 15,
      'dezesseis': 16,
      'dezessete': 17,
      'dezoito': 18,
      'dezenove': 19,
    };
    const tens = {
      'vinte': 20,
      'trinta': 30,
      'quarenta': 40,
      'cinquenta': 50,
      'sessenta': 60,
      'setenta': 70,
      'oitenta': 80,
      'noventa': 90,
    };
    const hundreds = {
      'cem': 100,
      'cento': 100,
      'duzentos': 200,
      'trezentos': 300,
      'quatrocentos': 400,
      'quinhentos': 500,
      'seiscentos': 600,
      'setecentos': 700,
      'oitocentos': 800,
      'novecentos': 900,
    };

    int? best;
    for (var i = 0; i < tokens.length; i++) {
      var total = 0;
      var current = 0;
      var consumed = 0;

      for (var j = i; j < tokens.length; j++) {
        final token = tokens[j];
        if (token == 'e') {
          consumed++;
          continue;
        }
        if (units.containsKey(token)) {
          current += units[token]!;
          consumed++;
          continue;
        }
        if (tens.containsKey(token)) {
          current += tens[token]!;
          consumed++;
          continue;
        }
        if (hundreds.containsKey(token)) {
          current += hundreds[token]!;
          consumed++;
          continue;
        }
        if (token == 'mil') {
          total += (current == 0 ? 1 : current) * 1000;
          current = 0;
          consumed++;
          continue;
        }
        if (token == 'reais' ||
            token == 'real' ||
            token == 'contos' ||
            token == 'conto') {
          consumed++;
          break;
        }
        break;
      }

      final value = total + current;
      if (consumed > 0 && value > 0) {
        best = value;
      }
    }
    return best?.toDouble();
  }

  String _normalizeAmountString(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'\s+'), '');

    final hasComma = value.contains(',');
    final hasDot = value.contains('.');

    if (hasComma && hasDot) {
      final commaIndex = value.lastIndexOf(',');
      final dotIndex = value.lastIndexOf('.');
      if (commaIndex > dotIndex) {
        return value.replaceAll('.', '').replaceAll(',', '.');
      }
      return value.replaceAll(',', '');
    }

    if (hasComma) {
      final parts = value.split(',');
      if (parts.length == 2 && parts[1].length == 3) {
        return parts.join();
      }
      return value.replaceAll(',', '.');
    }

    if (hasDot) {
      final parts = value.split('.');
      if (parts.length == 2 && parts[1].length == 3) {
        return parts.join();
      }
      if (parts.length > 2) {
        return parts.join();
      }
    }

    return value;
  }

  FinanceEntryType _entryTypeFromText(String text, {required bool isIncome}) {
    return _entryTypeFromTextOrNull(text, isIncome: isIncome) ??
        (isIncome ? FinanceEntryType.transferIn : FinanceEntryType.debit);
  }

  FinanceEntryType? _entryTypeFromTextOrNull(
    String text, {
    required bool isIncome,
  }) {
    if (text.contains('credito') ||
        text.contains('crédito') ||
        text.contains('cartao') ||
        text.contains('cartão')) {
      return FinanceEntryType.credit;
    }
    if (text.contains('debito') || text.contains('débito')) {
      return FinanceEntryType.debit;
    }
    if (text.contains('dinheiro')) return FinanceEntryType.cash;
    if (text.contains('boleto')) return FinanceEntryType.boleto;
    if (text.contains('pix')) {
      return isIncome ? FinanceEntryType.pixIn : FinanceEntryType.pixOut;
    }
    if (text.contains('transfer')) {
      return isIncome
          ? FinanceEntryType.transferIn
          : FinanceEntryType.transferOut;
    }
    return null;
  }

  FinanceCategory _categoryFromText(String text, {required bool isIncome}) {
    return _categoryFromTextOrNull(text, isIncome: isIncome) ??
        FinanceSeedData.getCategoryById(
          isIncome ? 'other_income' : 'other_expense',
        );
  }

  FinanceCategory? _categoryFromTextOrNull(
    String text, {
    required bool isIncome,
  }) {
    final normalized = _normalize(text);

    if (isIncome) {
      if (normalized.contains('salario') ||
          normalized.contains('salário') ||
          normalized.contains('pagamento')) {
        return FinanceSeedData.getCategoryById('salary');
      }
      if (normalized.contains('recebi') ||
          normalized.contains('ganhei') ||
          normalized.contains('entrada') ||
          normalized.contains('deposito') ||
          normalized.contains('depositaram')) {
        return FinanceSeedData.getCategoryById('other_income');
      }
      return null;
    }

    final keywordMap = <String, String>{
      'gasolina': 'transport_fuel',
      'combustivel': 'transport_fuel',
      'combustível': 'transport_fuel',
      'uber': 'transport_ride',
      '99': 'transport_ride',
      'onibus': 'transport_public',
      'ônibus': 'transport_public',
      'metro': 'transport_public',
      'metrô': 'transport_public',
      'trem': 'transport_public',
      'passagem': 'transport_public',
      'estacionamento': 'transport_parking',
      'pedagio': 'transport_toll',
      'pedágio': 'transport_toll',
      'ipva': 'transport_ipva',
      'mercado': 'food_market',
      'supermercado': 'food_market',
      'acougue': 'food_butcher',
      'açougue': 'food_butcher',
      'peixaria': 'food_butcher',
      'hortifruti': 'food_hortifruti',
      'fruta': 'food_hortifruti',
      'frutas': 'food_hortifruti',
      'verdura': 'food_hortifruti',
      'verduras': 'food_hortifruti',
      'legume': 'food_hortifruti',
      'padaria': 'food_bakery',
      'pao': 'food_bakery',
      'pão': 'food_bakery',
      'restaurante': 'leisure_restaurants',
      'sushi': 'leisure_restaurants',
      'lanche': 'leisure_restaurants',
      'ifood': 'leisure_delivery',
      'delivery': 'leisure_delivery',
      'agua': 'utility_water',
      'água': 'utility_water',
      'esgoto': 'utility_water',
      'luz': 'utility_energy',
      'energia': 'utility_energy',
      'gas': 'utility_gas',
      'gás': 'utility_gas',
      'internet': 'utility_internet',
      'wifi': 'utility_internet',
      'wi fi': 'utility_internet',
      'celular': 'utility_phone',
      'telefone': 'utility_phone',
      'aluguel': 'house_rent',
      'prestacao': 'house_rent',
      'prestação': 'house_rent',
      'financiamento': 'house_rent',
      'condominio': 'house_condo',
      'condomínio': 'house_condo',
      'iptu': 'house_iptu',
      'movel': 'house_furniture',
      'móvel': 'house_furniture',
      'decoracao': 'house_furniture',
      'decoração': 'house_furniture',
      'farmacia': 'health_medicine',
      'farmácia': 'health_medicine',
      'remedio': 'health_medicine',
      'remédio': 'health_medicine',
      'medicamento': 'health_medicine',
      'consulta': 'health_consult',
      'medico': 'health_consult',
      'médico': 'health_consult',
      'dentista': 'health_dentist',
      'terapia': 'health_therapy',
      'psicologo': 'health_therapy',
      'psicólogo': 'health_therapy',
      'academia': 'health_fitness',
      'suplemento': 'health_fitness',
      'higiene': 'health_hygiene',
      'roupa': 'shopping_clothes',
      'calcado': 'shopping_clothes',
      'calçado': 'shopping_clothes',
      'barbeiro': 'personal_beauty',
      'cabeleireiro': 'personal_beauty',
      'skincare': 'shopping_beauty',
      'cosmetico': 'shopping_beauty',
      'cosmético': 'shopping_beauty',
      'faculdade': 'education_school',
      'escola': 'education_school',
      'curso': 'education_courses',
      'livro': 'education_books',
      'material': 'education_books',
      'netflix': 'subscription_video',
      'disney': 'subscription_video',
      'spotify': 'subscription_music',
      'deezer': 'subscription_music',
      'chatgpt': 'subscription_chatgpt',
      'game pass': 'subscription_games',
      'ps plus': 'subscription_games',
      'skin': 'gaming_credits',
      'credito de jogo': 'gaming_credits',
      'crédito de jogo': 'gaming_credits',
      'pet': 'pet_food',
      'racao': 'pet_food',
      'ração': 'pet_food',
      'veterinario': 'pet_vet',
      'veterinário': 'pet_vet',
      'banho e tosa': 'pet_care',
      'cartao': 'debt_credit_card',
      'cartão': 'debt_credit_card',
      'fatura': 'debt_credit_card',
      'emprestimo': 'debt_loan',
      'empréstimo': 'debt_loan',
      'juros': 'debt_loan',
      'tarifa': 'bank_fees',
      'taxa': 'finance_taxes',
      'imposto': 'finance_taxes',
      'seguro': 'finance_other_insurance',
      'reserva': 'future_emergency',
      'caixinha': 'future_caixinha',
      'acoes': 'future_stocks',
      'ações': 'future_stocks',
      'fii': 'future_stocks',
      'cripto': 'future_crypto',
      'bitcoin': 'future_crypto',
      'viagem': 'leisure_travel',
      'cinema': 'leisure_cinema',
      'show': 'leisure_cinema',
      'presente': 'leisure_gifts',
      'hobbie': 'leisure_hobby',
      'hobby': 'leisure_hobby',
      'pc': 'shopping_hardware',
      'hardware': 'shopping_hardware',
      'eletronico': 'tech_devices',
      'eletrônico': 'tech_devices',
      'manutencao tech': 'tech_maintenance',
      'manutenção tech': 'tech_maintenance',
      'familia': 'family_support',
      'família': 'family_support',
      'filho': 'family_children',
      'criança': 'family_children',
      'crianca': 'family_children',
    };

    for (final entry in keywordMap.entries) {
      if (normalized.contains(_normalize(entry.key))) {
        return FinanceSeedData.getCategoryById(entry.value);
      }
    }

    final categories = FinanceSeedData.categories
        .where((item) => item.isIncomeCategory == false)
        .toList();

    for (final category in categories) {
      final name = _normalize(category.name);
      final tokens = name.split(' ').where((e) => e.length >= 4);
      if (tokens.any(normalized.contains)) {
        return category;
      }
    }

    return null;
  }

  String _buildFinanceTitle(
    String original,
    String normalized,
    FinanceCategory category, {
    required bool isIncome,
  }) {
    if (isIncome) {
      if (normalized.contains('salario') || normalized.contains('salário')) {
        return 'Salário';
      }
      if (normalized.contains('pagamento')) return 'Pagamento';
      if (normalized.contains('pix')) return 'Pix recebido';
      return 'Entrada';
    }

    final explicit = _extractExpenseItemTitle(original);
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final fallbackTitles = <String, String>{
      'gasolina': 'Gasolina',
      'mercado': 'Mercado',
      'internet': 'Internet',
      'aluguel': 'Aluguel',
      'ifood': 'Delivery',
      'delivery': 'Delivery',
      'uber': 'Uber',
      'farmacia': 'Farmácia',
      'farmácia': 'Farmácia',
      'fatura': 'Fatura do cartão',
    };

    for (final entry in fallbackTitles.entries) {
      if (normalized.contains(_normalize(entry.key))) {
        return entry.value;
      }
    }

    return category.name;
  }

  String? _extractExpenseItemTitle(String original) {
    var text = original.trim();

    text = text.replaceAll(
      RegExp(
        r'^(gastei|gastar|paguei|pagar|comprei|comprar|lancei|lancar|adicione?\s+gasto|adicionar\s+gasto|corrige\s+o\s+ultimo|corrigir\s+o\s+ultimo|o\s+ultimo\s+foi)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(RegExp(r'r\$\s*', caseSensitive: false), ' ');
    text = text.replaceAll(
      RegExp(r'\b(?:rs|reais?|real|conto|contos)\b', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\b\d+[\d\s\.,]*\b'), ' ');
    text = text.replaceAll(RegExp(r'\b\d+\s*x\b', caseSensitive: false), ' ');
    text = text.replaceAll(
      RegExp(
        r'\b(no|na|com|em)\s+(credito|crédito|debito|débito|pix|dinheiro|boleto|cartao|cartão|transferencia|transferência)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(credito|crédito|debito|débito|pix|dinheiro|boleto|cartao|cartão|transferencia|transferência)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'\b(hoje|amanha|amanhã|ontem)\b', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(segunda|terca|terça|quarta|quinta|sexta|sabado|sábado|domingo)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = _cleanLooseCommandWords(text);
    text = _sanitizeFinanceTitle(text);

    if (text.isEmpty) return null;
    final normalized = _normalize(text);
    if ({'gasto', 'despesa', 'saida', 'saída', 'compra'}.contains(normalized)) {
      return null;
    }
    return text;
  }

  String? _buildUpdateTitle(
    String original,
    String normalized,
    FinanceTransaction last,
  ) {
    final extracted = _extractExpenseItemTitle(original);
    if (extracted != null && extracted.isNotEmpty) return extracted;
    if (normalized.contains('salario') || normalized.contains('salário')) {
      return 'Salário';
    }
    return null;
  }

  String _financeSummary({
    required String title,
    required double amount,
    required FinanceCategory category,
    required FinanceEntryType entryType,
    required bool isIncome,
    required DateTime date,
  }) {
    final action = isIncome ? 'entrada' : 'gasto';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$action de ${_formatMoney(amount)} em "$title" (${category.name}, ${entryType.label.toLowerCase()}) em $day/$month';
  }

  String _formatMoney(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _stripWakeWords(String text) {
    return text.replaceFirst(
      RegExp(
        r'^\s*(vida|vi\s*da|assistente|amigo|ei)\s*[,:-]?\s+',
        caseSensitive: false,
      ),
      '',
    );
  }

  String _normalize(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var value = text.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      value = value.replaceAll(from[i], to[i]);
    }

    value = value
        .replaceAll(RegExp(r'[^a-z0-9/,:\sx]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const typoMap = <String, String>{
      'madruagada': 'madrugada',
      'manhaa': 'manha',
      'adione': 'adicione',
      'fes': 'festa',
      'feis': 'festa',
      'conserta tv': 'consertar tv',
    };

    typoMap.forEach((from, to) {
      value = value.replaceAll(from, to);
    });

    return value;
  }

  String _capitalize(String text) {
    final value = text.trim();
    if (value.isEmpty) return value;

    const prettyMap = <String, String>{
      'maca': 'Maçã',
      'cafe': 'Café',
      'agua': 'Água',
      'pao': 'Pão',
      'reuniao': 'Reunião',
      'medico': 'Médico',
      'farmacia': 'Farmácia',
      'gas': 'Gás',
      'onibus': 'Ônibus',
      'metro': 'Metrô',
      'consertar': 'Consertar',
      'tv': 'TV',
      'pc': 'PC',
      'ps': 'PS',
      'wifi': 'Wi‑Fi',
      'pix': 'Pix',
      'ipva': 'IPVA',
      'iptu': 'IPTU',
      'chatgpt': 'ChatGPT',
      'fii': 'FII',
      'fiis': 'FIIs',
      'cdb': 'CDB',
      'lci': 'LCI',
      'lca': 'LCA',
    };

    final words = value.split(RegExp(r'\s+'));
    return words
        .map((word) {
          if (word.isEmpty) return word;
          final normalized = _normalize(word);
          if (prettyMap.containsKey(normalized)) {
            return prettyMap[normalized]!;
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}

enum _FreeTextDomain { event, task, shopping }

class _ParsedTimePoint {
  const _ParsedTimePoint({required this.hour, required this.minute});

  final int hour;
  final int minute;
}

class _RepeatRule {
  const _RepeatRule({
    required this.type,
    this.weekdays = const <int>[],
    required this.confirmationText,
  });

  final TimelineRepeatType type;
  final List<int> weekdays;
  final String confirmationText;
}

class _TimeRange {
  const _TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
}
