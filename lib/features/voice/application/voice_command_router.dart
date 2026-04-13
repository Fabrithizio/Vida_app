// ============================================================================
// FILE: lib/features/voice/application/voice_command_router.dart
//
// O que faz:
// - entende comandos por voz para compras, agenda, tarefas da casa e finanças
// - melhora a limpeza da frase antes de interpretar o comando
// - reduz erros comuns de fala natural, conectivos soltos e palavras sobrando
// - deixa o fluxo compatível com o store atual do app, sem depender de internet
//
// Ideia desta versão:
// - manter o speech_to_text atual por enquanto
// - trocar o "cérebro" por um parser mais robusto
// - facilitar futuras melhorias sem mexer no restante do app
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

    final items = _extractShoppingItems(original);
    if (items.isEmpty) {
      return const VoiceCommandResult(
        message: 'Fale os itens depois de “coloca na lista…”.',
        handled: false,
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

    final taskText = _normalize(title);
    await homeTasks!.add(
      title: title,
      effort: _homeTaskEffortFromText(taskText),
      category: _homeTaskCategoryFromText(taskText),
      area: _homeTaskAreaFromText(taskText),
    );

    return VoiceCommandResult(
      message: 'Adicionei "$title" nas tarefas da casa.',
    );
  }

  Future<VoiceCommandResult?> _tryEventAdd(
    String original,
    String normalized,
  ) async {
    if (!_looksLikeEvent(normalized)) return null;

    final date = _extractDate(normalized);
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

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      timeRange.startHour,
      timeRange.startMinute,
    );
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      timeRange.endHour,
      timeRange.endMinute,
    );

    final event = TimelineBlock(
      id: 'voice_${DateTime.now().microsecondsSinceEpoch}',
      type: _timelineTypeFromText(_normalize(title)),
      title: title,
      start: start,
      end: end,
      notes: 'Criado por voz',
      reminderMinutes: 10,
    );

    if (timeline.hasConflict(event)) {
      return const VoiceCommandResult(
        message:
            'Esse horário bate com outro compromisso. Ajuste a fala e tente de novo.',
        handled: false,
      );
    }

    await timeline.add(event);
    return VoiceCommandResult(
      message:
          'Evento "$title" criado para ${_formatDate(date)} às ${_formatTime(start)}.',
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
    final byConnector = normalized.split(RegExp(r'\s+e\s+'));
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

    final hasQuantity = words.any((w) => RegExp(r'^\d+[a-z]*$').hasMatch(w));
    final shouldSplitIntoSingles =
        words.length >= 2 &&
        words.length <= 5 &&
        !hasQuantity &&
        !words.any(joinerWords.contains);

    if (shouldSplitIntoSingles) {
      for (final word in words) {
        yield word;
      }
      return;
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
        r'^(na|no|de|do|da|pra|para|pro|o|a|os|as|um|uma)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'\s+(na|no|de|do|da|pra|para|pro|o|a|os|as|um|uma)$',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    final lower = text.toLowerCase();
    if (text.isEmpty) return '';
    if (text.length == 1 && {'a', 'e', 'o'}.contains(lower)) return '';
    if ({'de', 'do', 'da', 'na', 'no', 'pra', 'para'}.contains(lower)) {
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
        r'\b(tarefas?\s+da\s+casa|afazeres?\s+da\s+casa)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    text = _cleanLooseCommandWords(text);
    if (text.isEmpty) return '';
    return _capitalize(text);
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
        text.contains('compromisso');
    final hasDate = _extractDate(text) != null;
    final hasTime = _extractTimeRange(text) != null;
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
        text.contains('aula');

    return hasSchedulingVerb || (hasDate && hasTime && hasTypicalTitle);
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

    if (text.contains('hoje')) return today;
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

    for (final entry in weekdays.entries) {
      if (text.contains(entry.key)) {
        final diff = (entry.value - today.weekday + 7) % 7;
        final days = diff == 0 ? 7 : diff;
        return today.add(Duration(days: days));
      }
    }

    return null;
  }

  _TimeRange? _extractTimeRange(String text) {
    final fullPatterns = [
      RegExp(
        r'(?:das\s+|da\s+|de\s+)?(\d{1,2})(?::|h)?(\d{0,2})\s*(?:ate|até|as|às|a)\s*(\d{1,2})(?::|h)?(\d{0,2})',
      ),
      RegExp(r'\b(\d{1,2}):(\d{2})\s*(?:ate|até|-|a)\s*(\d{1,2}):(\d{2})\b'),
      RegExp(
        r'\b(\d{1,2})\s*h(?:oras?)?\s*(?:ate|até|a)\s*(\d{1,2})\s*h(?:oras?)?\b',
      ),
    ];

    for (final pattern in fullPatterns) {
      final full = pattern.firstMatch(text);
      if (full == null) continue;

      int? sh;
      int sm = 0;
      int? eh;
      int em = 0;

      if (full.groupCount >= 4) {
        sh = int.tryParse(full.group(1)!);
        sm = _parseMinute(full.group(2));
        eh = int.tryParse(full.group(3)!);
        em = _parseMinute(full.group(4));
      } else if (full.groupCount == 2) {
        sh = int.tryParse(full.group(1)!);
        eh = int.tryParse(full.group(2)!);
      }

      if (sh != null && eh != null) {
        return _TimeRange(
          startHour: sh,
          startMinute: sm,
          endHour: eh,
          endMinute: em,
        );
      }
    }

    final single =
        RegExp(r'(?:as|às|a)\s*(\d{1,2})(?::|h)?(\d{0,2})').firstMatch(text) ??
        RegExp(r'\b(\d{1,2})\s*h(?:oras?)?\b').firstMatch(text);
    if (single != null) {
      final sh = int.tryParse(single.group(1)!);
      final sm = _parseMinute(single.groupCount >= 2 ? single.group(2) : null);
      if (sh != null) {
        final endHour = (sh + 1) % 24;
        return _TimeRange(
          startHour: sh,
          startMinute: sm,
          endHour: endHour,
          endMinute: sm,
        );
      }
    }

    return null;
  }

  int _parseMinute(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  String _extractEventTitle(String original) {
    var text = original.trim();
    text = text.replaceAll(
      RegExp(
        r'^(agenda|agendar|marca|marcar|cria\s+evento|criar\s+evento|adiciona\s+evento|adicionar\s+evento|evento|compromisso)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(na\s+agenda|no\s+calendario|no\s+calendário|no\s+meu\s+dia)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(amanha|amanhã|hoje|ontem|segunda|terca|terça|quarta|quinta|sexta|sabado|sábado|domingo)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b'), ' ');
    text = text.replaceAll(
      RegExp(
        r'(?:das\s+|da\s+|de\s+)?\d{1,2}(?::\d{1,2}|h\d{0,2}|h)?\s*(?:ate|até|as|às|a)?\s*\d{0,2}(?::\d{1,2}|h\d{0,2}|h)?',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\bhoras?\b', caseSensitive: false), ' ');
    text = text.replaceAll(
      RegExp(
        r'\b(das|da|de|as|às|até|ate|para|pra|na|no|em)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = _cleanLooseCommandWords(text);
    if (text.isEmpty) return '';
    return _capitalize(text);
  }

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

    if (text.isEmpty) return null;
    final normalized = _normalize(text);
    if ({'gasto', 'despesa', 'saida', 'saída', 'compra'}.contains(normalized)) {
      return null;
    }
    return _capitalize(text);
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

    return value;
  }

  String _capitalize(String text) {
    final value = text.trim();
    if (value.isEmpty) return value;
    final words = value.split(RegExp(r'\s+'));
    return words
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
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
