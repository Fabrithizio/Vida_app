// ============================================================================
// FILE: lib/features/voice/application/voice_command_router.dart
//
// O que faz:
// - entende comandos por voz para compras, tarefas da casa, agenda e finanças
// - aceita fala mais natural e informal
// - para finanças, sempre pede confirmação antes de salvar/editar/remover
// - devolve mensagens curtas para o hub de voz mostrar ao usuário
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
    final text = transcript.trim();
    if (text.isEmpty) {
      return const VoiceCommandResult(
        message: 'Não entendi. Tente de novo.',
        handled: false,
      );
    }

    final normalized = _normalize(text);

    final financeRemove = await _tryFinanceRemove(text, normalized);
    if (financeRemove != null) return financeRemove;

    final financeUpdate = await _tryFinanceUpdate(text, normalized);
    if (financeUpdate != null) return financeUpdate;

    final financeCreate = await _tryFinanceCreate(text, normalized);
    if (financeCreate != null) return financeCreate;

    final shoppingResult = await _tryShoppingAdd(text, normalized);
    if (shoppingResult != null) return shoppingResult;

    final homeTaskResult = await _tryHomeTaskAdd(text, normalized);
    if (homeTaskResult != null) return homeTaskResult;

    final eventResult = await _tryEventAdd(text, normalized);
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

    final effort = _homeTaskEffortFromText(normalized);
    final category = _homeTaskCategoryFromText(normalized);
    final area = _homeTaskAreaFromText(normalized);

    await homeTasks!.add(
      title: title,
      effort: effort,
      category: category,
      area: area,
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

    final amount = _extractAmount(normalized);
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
      message: 'Entendi: $summary',
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

    final newAmount = _extractAmount(normalized);
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
            'Para corrigir o último lançamento, diga o que quer mudar. Ex.: “corrige o último gasto para 25”.',
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
      message: 'Entendi: atualizar o último lançamento para $summary',
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
          'Entendi: remover o último lançamento "${last.title}" no valor de ${_formatMoney(last.amount)}.',
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

  bool _looksLikeShoppingAdd(String normalized) {
    final hasVerb =
        normalized.contains('coloca') ||
        normalized.contains('adic') ||
        normalized.contains('bota') ||
        normalized.contains('poe ') ||
        normalized.contains('põe ');
    final hasList =
        normalized.contains('lista') || normalized.contains('compr');
    return hasVerb && hasList;
  }

  bool _looksLikeHomeTask(String normalized) {
    final hasVerb =
        normalized.contains('adicion') ||
        normalized.contains('coloca') ||
        normalized.contains('bota') ||
        normalized.contains('cria') ||
        normalized.contains('anota');
    final hasContext =
        normalized.contains('tarefa') ||
        normalized.contains('afazer') ||
        normalized.contains('a fazer') ||
        normalized.contains('casa') ||
        normalized.contains('banheiro') ||
        normalized.contains('cozinha') ||
        normalized.contains('quarto') ||
        normalized.contains('lavanderia') ||
        normalized.contains('sala');
    return hasVerb && hasContext;
  }

  bool _looksLikeEvent(String normalized) {
    if (normalized.contains('lista') || normalized.contains('compr')) {
      return false;
    }
    if (_looksLikeHomeTask(normalized)) {
      return false;
    }
    return normalized.contains('agenda') ||
        normalized.contains('agenda ') ||
        normalized.contains('agendar') ||
        normalized.contains('marca ') ||
        normalized.contains('marcar ') ||
        normalized.contains('cria evento') ||
        normalized.contains('criar evento') ||
        normalized.contains('compromisso') ||
        normalized.contains('reuniao') ||
        normalized.contains('reuni') ||
        normalized.contains('consulta') ||
        normalized.contains('treino');
  }

  bool _looksLikeFinance(String normalized) {
    return normalized.contains('reais') ||
        normalized.contains('real') ||
        normalized.contains('r\$') ||
        normalized.contains('gastei') ||
        normalized.contains('recebi') ||
        normalized.contains('ganhei') ||
        normalized.contains('entrou') ||
        normalized.contains('caiu') ||
        normalized.contains('paguei') ||
        normalized.contains('comprei') ||
        normalized.contains('debito') ||
        normalized.contains('credito') ||
        normalized.contains('pix') ||
        normalized.contains('boleto') ||
        normalized.contains('salario') ||
        normalized.contains('freela') ||
        normalized.contains('gasolina') ||
        normalized.contains('mercado') ||
        normalized.contains('aluguel');
  }

  bool _looksLikeIncome(String normalized) {
    return normalized.contains('recebi') ||
        normalized.contains('ganhei') ||
        normalized.contains('entrou') ||
        normalized.contains('caiu') ||
        normalized.contains('deposit') ||
        normalized.contains('salario') ||
        normalized.contains('pagamento') ||
        normalized.contains('freela') ||
        normalized.contains('freelance');
  }

  List<String> _extractShoppingItems(String original) {
    var working = original.trim();

    working = working.replaceAll(
      RegExp(
        r'^\s*(coloca|coloque|adiciona|adicionar|bota|botar|poe|põe)\b',
        caseSensitive: false,
      ),
      '',
    );

    working = working.replaceAll(
      RegExp(
        r'\b(na lista( de compras)?|na compra|nas compras|de compras)\b',
        caseSensitive: false,
      ),
      '',
    );

    working = working.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (working.isEmpty) return const [];

    final pieces = working
        .split(RegExp(r'\s*,\s*|\s+e\s+', caseSensitive: false))
        .map(_sanitizeListItem)
        .where((e) => e.isNotEmpty)
        .toList();

    return pieces;
  }

  String _sanitizeListItem(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^[•\-–—]+\s*'), '');
    text = text.replaceAll(RegExp(r'^(r|erre)\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^de\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^um\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^uma\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\.$'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String _extractHomeTaskTitle(String original) {
    var title = original.trim();
    title = title.replaceAll(
      RegExp(
        r'^\s*(adiciona|adicionar|coloca|coloque|bota|botar|cria|criar|anota|anotar)\b',
        caseSensitive: false,
      ),
      '',
    );
    title = title.replaceAll(
      RegExp(
        r'\b(nas tarefas da casa|na tarefa da casa|na lista da casa|em casa|pra casa|para casa|nos afazeres de casa|nos afazeres da casa|nas tarefas|nos afazeres)\b',
        caseSensitive: false,
      ),
      '',
    );
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return '';
    return _capitalize(title);
  }

  HomeTaskEffort _homeTaskEffortFromText(String normalized) {
    if (normalized.contains('consert') ||
        normalized.contains('organiza guarda') ||
        normalized.contains('faxina') ||
        normalized.contains('limpa o banheiro inteiro') ||
        normalized.contains('limpar o banheiro') ||
        normalized.contains('pint') ||
        normalized.contains('vazamento')) {
      return HomeTaskEffort.major;
    }
    return HomeTaskEffort.quick;
  }

  HomeTaskCategory _homeTaskCategoryFromText(String normalized) {
    if (normalized.contains('consert') ||
        normalized.contains('troca') ||
        normalized.contains('vazamento') ||
        normalized.contains('reparo')) {
      return HomeTaskCategory.maintenance;
    }
    if (normalized.contains('organiza') ||
        normalized.contains('guardar') ||
        normalized.contains('arruma') ||
        normalized.contains('arrumar')) {
      return HomeTaskCategory.organization;
    }
    return HomeTaskCategory.cleaning;
  }

  HomeTaskArea _homeTaskAreaFromText(String normalized) {
    if (normalized.contains('cozinha')) return HomeTaskArea.kitchen;
    if (normalized.contains('banheiro')) return HomeTaskArea.bathroom;
    if (normalized.contains('quarto')) return HomeTaskArea.bedroom;
    if (normalized.contains('sala')) return HomeTaskArea.livingRoom;
    if (normalized.contains('lavanderia') ||
        normalized.contains('lavar roupa')) {
      return HomeTaskArea.laundry;
    }
    if (normalized.contains('quintal') || normalized.contains('garagem')) {
      return HomeTaskArea.outdoor;
    }
    if (normalized.contains('casa toda')) return HomeTaskArea.wholeHouse;
    return HomeTaskArea.other;
  }

  String _extractEventTitle(String original) {
    var title = original.trim();
    title = title.replaceAll(
      RegExp(
        r'^\s*(agenda|agendar|marca|marcar|cria|criar|anota|anotar)\b',
        caseSensitive: false,
      ),
      '',
    );
    title = title.replaceAll(
      RegExp(r'\b(evento|compromisso)\b', caseSensitive: false),
      '',
    );
    title = title.replaceAll(
      RegExp(
        r'\b(hoje|amanha|amanhã|depois de amanha|depois de amanhã|segunda|terca|terça|quarta|quinta|sexta|sabado|sábado|domingo)\b.*$',
        caseSensitive: false,
      ),
      '',
    );
    title = title.replaceAll(
      RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b.*$', caseSensitive: false),
      '',
    );
    title = title.replaceAll(
      RegExp(r'\b(as|às|das)\b.*$', caseSensitive: false),
      '',
    );
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _capitalize(title);
  }

  _ParsedTimeRange? _extractTimeRange(String normalized) {
    final explicitRange = RegExp(
      r'\b(?:das\s+)?(\d{1,2})(?::|h)?(\d{0,2})\s*(?:ate|até|as|às|a)\s*(\d{1,2})(?::|h)?(\d{0,2})',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (explicitRange != null) {
      final sh = int.tryParse(explicitRange.group(1) ?? '');
      final sm = _minuteValue(explicitRange.group(2));
      final eh = int.tryParse(explicitRange.group(3) ?? '');
      final em = _minuteValue(explicitRange.group(4));
      if (sh != null && eh != null) {
        final startHour = _adjustHourByPartOfDay(normalized, sh);
        final endHour = _adjustHourByPartOfDay(normalized, eh, isEnd: true);
        return _ParsedTimeRange(startHour, sm, endHour, em);
      }
    }

    final one = RegExp(
      r'\b(?:as|às|a|das)\s*(\d{1,2})(?::|h)?(\d{0,2})',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (one != null) {
      final h = int.tryParse(one.group(1) ?? '');
      final m = _minuteValue(one.group(2));
      if (h != null) {
        final startHour = _adjustHourByPartOfDay(normalized, h);
        return _ParsedTimeRange(startHour, m, startHour + 1, m);
      }
    }

    final simple = RegExp(
      r'\b(\d{1,2})\s*(da manha|da manhã|da tarde|da noite)\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (simple != null) {
      final h = int.tryParse(simple.group(1) ?? '');
      if (h != null) {
        final adjusted = _adjustHourByPartOfDay(normalized, h);
        return _ParsedTimeRange(adjusted, 0, adjusted + 1, 0);
      }
    }

    return null;
  }

  int _minuteValue(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw.padRight(2, '0')) ?? 0;
  }

  int _adjustHourByPartOfDay(
    String normalized,
    int hour, {
    bool isEnd = false,
  }) {
    if (hour == 24) return 23;
    var result = hour.clamp(0, 23);
    if (normalized.contains('meio dia')) return 12;
    if (normalized.contains('meia noite')) return 0;
    final hasMorning =
        normalized.contains('manha') || normalized.contains('manhã');
    final hasAfternoon = normalized.contains('tarde');
    final hasNight = normalized.contains('noite');
    if (hasMorning && result == 12) return 0;
    if ((hasAfternoon || hasNight) && result < 12) result += 12;
    if (isEnd && result <= 0) return 1;
    return result.clamp(0, 23);
  }

  DateTime? _extractDate(String normalized) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (normalized.contains('depois de amanha') ||
        normalized.contains('depois de amanhã')) {
      return today.add(const Duration(days: 2));
    }
    if (normalized.contains('amanha') || normalized.contains('amanhã')) {
      return today.add(const Duration(days: 1));
    }
    if (normalized.contains('hoje')) {
      return today;
    }
    if (normalized.contains('ontem')) {
      return today.subtract(const Duration(days: 1));
    }

    final slash = RegExp(
      r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b',
    ).firstMatch(normalized);
    if (slash != null) {
      final day = int.tryParse(slash.group(1) ?? '');
      final month = int.tryParse(slash.group(2) ?? '');
      final yearRaw = slash.group(3);
      if (day != null && month != null) {
        var year = now.year;
        if (yearRaw != null && yearRaw.isNotEmpty) {
          year = int.tryParse(yearRaw) ?? year;
          if (year < 100) year += 2000;
        }
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
      if (normalized.contains(entry.key)) {
        var diff = entry.value - today.weekday;
        if (diff <= 0) diff += 7;
        return today.add(Duration(days: diff));
      }
    }

    return null;
  }

  TimelineBlockType _timelineTypeFromText(String normalizedTitle) {
    if (normalizedTitle.contains('treino') ||
        normalizedTitle.contains('academ')) {
      return TimelineBlockType.workout;
    }
    if (normalizedTitle.contains('estud') ||
        normalizedTitle.contains('prova')) {
      return TimelineBlockType.study;
    }
    if (normalizedTitle.contains('dent') ||
        normalizedTitle.contains('consulta') ||
        normalizedTitle.contains('medic') ||
        normalizedTitle.contains('exame')) {
      return TimelineBlockType.health;
    }
    if (normalizedTitle.contains('descanso') ||
        normalizedTitle.contains('sono')) {
      return TimelineBlockType.rest;
    }
    if (normalizedTitle.contains('anivers') ||
        normalizedTitle.contains('encontro') ||
        normalizedTitle.contains('amigo') ||
        normalizedTitle.contains('famil')) {
      return TimelineBlockType.social;
    }
    return TimelineBlockType.event;
  }

  double? _extractAmount(String normalized) {
    final match = RegExp(
      r'(?:r\$\s*)?(\d{1,3}(?:[\.,]\d{3})*(?:[\.,]\d{1,2})?|\d+(?:[\.,]\d{1,2})?)',
    ).firstMatch(normalized);
    if (match == null) return null;
    final raw = (match.group(1) ?? '').trim();
    if (raw.isEmpty) return null;

    var cleaned = raw;
    if (cleaned.contains(',') && cleaned.contains('.')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    }

    return double.tryParse(cleaned);
  }

  FinanceEntryType _entryTypeFromText(
    String normalized, {
    required bool isIncome,
  }) {
    if (normalized.contains('credito') || normalized.contains('cartao')) {
      return FinanceEntryType.credit;
    }
    if (normalized.contains('debito')) {
      return FinanceEntryType.debit;
    }
    if (normalized.contains('boleto')) {
      return FinanceEntryType.boleto;
    }
    if (normalized.contains('dinheiro')) {
      return FinanceEntryType.cash;
    }
    if (normalized.contains('pix')) {
      return isIncome ? FinanceEntryType.pixIn : FinanceEntryType.pixOut;
    }
    if (normalized.contains('transfer')) {
      return isIncome
          ? FinanceEntryType.transferIn
          : FinanceEntryType.transferOut;
    }
    return isIncome ? FinanceEntryType.transferIn : FinanceEntryType.debit;
  }

  FinanceEntryType? _entryTypeFromTextOrNull(
    String normalized, {
    required bool isIncome,
  }) {
    if (normalized.contains('credito') || normalized.contains('cartao')) {
      return FinanceEntryType.credit;
    }
    if (normalized.contains('debito')) {
      return FinanceEntryType.debit;
    }
    if (normalized.contains('boleto')) {
      return FinanceEntryType.boleto;
    }
    if (normalized.contains('dinheiro')) {
      return FinanceEntryType.cash;
    }
    if (normalized.contains('pix')) {
      return isIncome ? FinanceEntryType.pixIn : FinanceEntryType.pixOut;
    }
    if (normalized.contains('transfer')) {
      return isIncome
          ? FinanceEntryType.transferIn
          : FinanceEntryType.transferOut;
    }
    return null;
  }

  FinanceCategory _categoryFromText(
    String normalized, {
    required bool isIncome,
  }) {
    final found = _categoryFromTextOrNull(normalized, isIncome: isIncome);
    if (found != null) return found;
    return FinanceSeedData.getCategoryById(
      isIncome ? 'other_income' : 'other_expense',
    );
  }

  FinanceCategory? _categoryFromTextOrNull(
    String normalized, {
    required bool isIncome,
  }) {
    if (isIncome) {
      if (normalized.contains('salario') || normalized.contains('salário')) {
        return FinanceSeedData.getCategoryById('salary');
      }
      return FinanceSeedData.getCategoryById('other_income');
    }

    if (normalized.contains('gasolina') ||
        normalized.contains('uber') ||
        normalized.contains('onibus') ||
        normalized.contains('ônibus') ||
        normalized.contains('combust')) {
      return FinanceSeedData.getCategoryById('transport');
    }
    if (normalized.contains('mercado') ||
        normalized.contains('supermercado') ||
        normalized.contains('almoco') ||
        normalized.contains('almoço') ||
        normalized.contains('comida') ||
        normalized.contains('lanche') ||
        normalized.contains('janta')) {
      return FinanceSeedData.getCategoryById('food');
    }
    if (normalized.contains('farmac') ||
        normalized.contains('remedio') ||
        normalized.contains('remédio') ||
        normalized.contains('medico') ||
        normalized.contains('médico')) {
      return FinanceSeedData.getCategoryById('health');
    }
    if (normalized.contains('cinema') ||
        normalized.contains('lazer') ||
        normalized.contains('jogo') ||
        normalized.contains('stream')) {
      return FinanceSeedData.getCategoryById('leisure');
    }
    if (normalized.contains('camisa') ||
        normalized.contains('roupa') ||
        normalized.contains('compra')) {
      return FinanceSeedData.getCategoryById('shopping');
    }
    if (normalized.contains('aluguel') ||
        normalized.contains('energia') ||
        normalized.contains('agua') ||
        normalized.contains('água') ||
        normalized.contains('internet') ||
        normalized.contains('casa')) {
      return FinanceSeedData.getCategoryById('home');
    }
    if (normalized.contains('curso') ||
        normalized.contains('faculdade') ||
        normalized.contains('estudo')) {
      return FinanceSeedData.getCategoryById('education');
    }

    return null;
  }

  String _buildFinanceTitle(
    String normalized,
    FinanceCategory category, {
    required bool isIncome,
  }) {
    if (isIncome) {
      if (category.id == 'salary') return 'Salário';
      if (normalized.contains('freela') || normalized.contains('freelance')) {
        return 'Freelance';
      }
      if (normalized.contains('pagamento')) return 'Pagamento';
      return 'Entrada';
    }

    switch (category.id) {
      case 'transport':
        if (normalized.contains('gasolina') || normalized.contains('combust')) {
          return 'Combustível';
        }
        return 'Transporte';
      case 'food':
        if (normalized.contains('mercado') ||
            normalized.contains('supermercado')) {
          return 'Supermercado';
        }
        return 'Alimentação';
      case 'health':
        return 'Saúde';
      case 'shopping':
        return 'Compras';
      case 'leisure':
        return 'Lazer';
      case 'home':
        return 'Casa';
      case 'education':
        return 'Estudos';
      default:
        return 'Saída';
    }
  }

  String? _buildUpdateTitle(String normalized, FinanceTransaction last) {
    if (normalized.contains('gasolina') || normalized.contains('combust')) {
      return 'Combustível';
    }
    if (normalized.contains('mercado') || normalized.contains('supermercado')) {
      return 'Supermercado';
    }
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
    final kind = isIncome ? 'entrada' : 'gasto';
    return '$kind de ${_formatMoney(amount)} em ${title.toLowerCase()} '
        '(${category.name.toLowerCase()}, ${entryType.label.toLowerCase()}) '
        'em ${_formatDate(date)}';
  }

  String _formatMoney(double value) {
    final cents = ((value - value.truncateToDouble()) * 100).round();
    if (cents == 0) {
      return 'R\$ ${value.toStringAsFixed(0)}';
    }
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _capitalize(String text) {
    if (text.trim().isEmpty) return '';
    final trimmed = text.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _normalize(String text) {
    const from = 'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇç';
    const to = 'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCc';
    var out = text;
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    out = out.toLowerCase();
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }
}

class _ParsedTimeRange {
  const _ParsedTimeRange(
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
  );

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
}
