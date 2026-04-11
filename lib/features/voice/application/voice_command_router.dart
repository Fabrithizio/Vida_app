// ============================================================================
// FILE: lib/features/voice/application/voice_command_router.dart
//
// O que faz:
// - entende comandos por voz para compras, tarefas da casa, agenda e finanças
// - aceita fala natural/informal
// - confirma lançamentos financeiros antes de salvar
// - corrige/remover o último lançamento financeiro por voz
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
    final original = transcript.trim();
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

    final financeCreate = await _tryFinanceCreate(original, normalized);
    if (financeCreate != null) return financeCreate;

    final shoppingResult = await _tryShoppingAdd(original, normalized);
    if (shoppingResult != null) return shoppingResult;

    final homeTaskResult = await _tryHomeTaskAdd(original, normalized);
    if (homeTaskResult != null) return homeTaskResult;

    final eventResult = await _tryEventAdd(original, normalized);
    if (eventResult != null) return eventResult;

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

    await homeTasks!.add(
      title: title,
      effort: _homeTaskEffortFromText(_normalize(title)),
      category: _homeTaskCategoryFromText(_normalize(title)),
      area: _homeTaskAreaFromText(_normalize(title)),
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
    final title = _buildFinanceTitle(normalized, category, isIncome: isIncome);

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
    if (!(normalized.contains('ultimo') || normalized.contains('ultim'))) {
      return null;
    }
    if (!(normalized.contains('corrig') ||
        normalized.contains('alter') ||
        normalized.contains('mud') ||
        normalized.contains('edita'))) {
      return null;
    }

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
    final newTitle = _buildUpdateTitle(normalized, last);

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
        (normalized.contains('ultimo') || normalized.contains('ultim')))) {
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

  bool _looksLikeShoppingAdd(String text) {
    final hasVerb =
        text.contains('coloca') ||
        text.contains('adiciona') ||
        text.contains('adicionar') ||
        text.contains('bota') ||
        text.contains('poe') ||
        text.contains('põe');
    final hasContext = text.contains('lista') || text.contains('compras');
    return hasVerb && hasContext;
  }

  List<String> _extractShoppingItems(String original) {
    var text = original.trim();

    text = text.replaceFirst(
      RegExp(
        r'^\s*(coloca|colocar|adiciona|adicionar|bota|botar|poe|põe)\s+',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'\s+(na|pra|para)\s+lista(?:\s+de\s+compras|\s+do\s+mercado)?\s*$|\s+nas\s+compras\s*$|\s+de\s+compras\s*$|\s+na\s+lista\s*$|\s+lista\s+de\s+compras\s*$|\s+na\s+lista\s+de\s+compras\s*$',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(RegExp(r'\s+e\s+', caseSensitive: false), ',');
    text = text.replaceAll(';', ',');

    final rawParts = text
        .split(',')
        .map(_sanitizeShoppingItem)
        .where((e) => e.isNotEmpty)
        .toList();

    return rawParts;
  }

  String _sanitizeShoppingItem(String raw) {
    var text = raw.trim();
    text = text.replaceAll(
      RegExp(
        r'^(coloca|colocar|adiciona|adicionar|bota|botar|poe|põe)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\b(lista|compras)\b', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'^r\s+', caseSensitive: false), '');
    text = text.replaceAll(
      RegExp(r'^(o|a|os|as|um|uma)\s+', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  bool _looksLikeHomeTask(String text) {
    return text.contains('tarefa da casa') ||
        text.contains('tarefas da casa') ||
        text.contains('afazer') ||
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
        r'^\s*(adiciona|adicionar|coloca|colocar|bota|botar|anota|anotar)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(r'(nas|na|pra|para|em|de)', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'(tarefas?\s+da\s+casa|tarefa\s+da\s+casa|tarefas?|casa)',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    if (RegExp(
      r'^(adiciona|adicionar|coloca|colocar|bota|botar|anota|anotar)$',
      caseSensitive: false,
    ).hasMatch(text)) {
      return '';
    }
    return text[0].toUpperCase() + text.substring(1);
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
    return text.contains('agenda') ||
        text.contains('agendar') ||
        text.contains('marca ') ||
        text.contains('marcar') ||
        text.contains('reuniao') ||
        text.contains('reunião') ||
        text.contains('consulta') ||
        text.contains('compromisso') ||
        text.contains('evento');
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
    if (text.contains('amanha') || text.contains('amanhã')) {
      return today.add(const Duration(days: 1));
    }
    if (text.contains('depois de amanha') ||
        text.contains('depois de amanhã')) {
      return today.add(const Duration(days: 2));
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
    final full = RegExp(
      r'(?:das\s+)?(\d{1,2})(?::|h)?(\d{0,2})\s*(?:ate|até|as|às|a)\s*(\d{1,2})(?::|h)?(\d{0,2})',
    ).firstMatch(text);
    if (full != null) {
      final sh = int.tryParse(full.group(1)!);
      final sm = _parseMinute(full.group(2));
      final eh = int.tryParse(full.group(3)!);
      final em = _parseMinute(full.group(4));
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
        r'^(agenda|agendar|marca|marcar|cria evento|evento|compromisso)\s+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(amanha|amanhã|hoje|segunda|terca|terça|quarta|quinta|sexta|sabado|sábado|domingo)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b'), ' ');
    text = text.replaceAll(
      RegExp(
        r'(?:das\s+)?\d{1,2}(?::\d{1,2}|h\d{0,2}|h)?\s*(?:ate|até|as|às|a)?\s*\d{0,2}(?::\d{1,2}|h\d{0,2}|h)?',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  bool _looksLikeFinance(String text) {
    return text.contains('gastei') ||
        text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('salario') ||
        text.contains('salário') ||
        text.contains('paguei') ||
        text.contains('comprei') ||
        text.contains('pix') ||
        text.contains('debito') ||
        text.contains('débito') ||
        text.contains('credito') ||
        text.contains('crédito') ||
        text.contains('real') ||
        text.contains('reais');
  }

  bool _looksLikeIncome(String text) {
    return text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('salario') ||
        text.contains('salário') ||
        text.contains('pagamento') ||
        text.contains('entrada') ||
        text.contains('caiu');
  }

  double? _extractAmount(String text) {
    final source = text.toLowerCase();

    final moneyContext = RegExp(
      r'(\d[\d\s\.,]*\d|\d)\s*(reais|real|r\$)?',
      caseSensitive: false,
    );

    final matches = moneyContext
        .allMatches(source)
        .map((m) => m.group(1) ?? '')
        .where((m) => m.trim().isNotEmpty)
        .toList();

    if (matches.isEmpty) return null;

    matches.sort((a, b) => b.length.compareTo(a.length));

    for (final raw in matches) {
      final normalized = _normalizeAmountString(raw);
      final value = double.tryParse(normalized);
      if (value != null) return value;
    }

    return null;
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
    if (isIncome) {
      if (text.contains('salario') ||
          text.contains('salário') ||
          text.contains('pagamento')) {
        return FinanceSeedData.getCategoryById('salary');
      }
      if (text.contains('recebi') ||
          text.contains('ganhei') ||
          text.contains('entrada')) {
        return FinanceSeedData.getCategoryById('other_income');
      }
      return null;
    }

    final map = <String, String>{
      'gasolina': 'transport',
      'combust': 'transport',
      'uber': 'transport',
      'onibus': 'transport',
      'ônibus': 'transport',
      'mercado': 'food',
      'comida': 'food',
      'ifood': 'food',
      'restaurante': 'food',
      'farmacia': 'health',
      'farmácia': 'health',
      'medico': 'health',
      'médico': 'health',
      'remedio': 'health',
      'remédio': 'health',
      'roupa': 'shopping',
      'presente': 'shopping',
      'compras': 'shopping',
      'shopping': 'shopping',
      'cinema': 'leisure',
      'lazer': 'leisure',
      'jogo': 'leisure',
      'internet': 'home',
      'aluguel': 'home',
      'energia': 'home',
      'agua': 'home',
      'água': 'home',
      'faculdade': 'education',
      'curso': 'education',
      'escola': 'education',
    };

    for (final entry in map.entries) {
      if (text.contains(entry.key)) {
        return FinanceSeedData.getCategoryById(entry.value);
      }
    }
    return null;
  }

  String _buildFinanceTitle(
    String normalized,
    FinanceCategory category, {
    required bool isIncome,
  }) {
    if (isIncome) {
      if (normalized.contains('salario') || normalized.contains('salário')) {
        return 'Salário';
      }
      if (normalized.contains('pagamento')) return 'Pagamento';
      return 'Entrada';
    }

    if (normalized.contains('gasolina') || normalized.contains('combust')) {
      return 'Gasolina';
    }
    if (normalized.contains('mercado')) return 'Mercado';
    if (normalized.contains('internet')) return 'Internet';
    if (normalized.contains('aluguel')) return 'Aluguel';
    if (normalized.contains('ifood') || normalized.contains('restaurante')) {
      return 'Alimentação';
    }
    return category.name;
  }

  String? _buildUpdateTitle(String normalized, FinanceTransaction last) {
    if (normalized.contains('gasolina')) return 'Gasolina';
    if (normalized.contains('mercado')) return 'Mercado';
    if (normalized.contains('internet')) return 'Internet';
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

  String _normalize(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var value = text.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      value = value.replaceAll(from[i], to[i]);
    }
    value = value
        .replaceAll(RegExp(r'[^a-z0-9/,:\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value;
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
