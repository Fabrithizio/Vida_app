// ============================================================================
// FILE: lib/features/voice/application/voice_command_router.dart
//
// O que faz:
// - entende comandos por voz de compras, agenda, tarefas da casa e finanças
// - para finanças, sempre pede confirmação antes de salvar
// - permite corrigir/remover o último lançamento financeiro por voz
// ============================================================================

import 'package:flutter/material.dart';
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

    final financeRemove = await _tryFinanceRemove(normalized);
    if (financeRemove != null) return financeRemove;

    final financeUpdate = await _tryFinanceUpdate(text, normalized);
    if (financeUpdate != null) return financeUpdate;

    final financeCreate = await _tryFinanceCreate(text, normalized);
    if (financeCreate != null) return financeCreate;

    if (_looksLikeShoppingAdd(normalized)) {
      final items = _extractShoppingItems(text);
      if (items.isEmpty) {
        return const VoiceCommandResult(
          message: 'Fale os itens depois de “coloca na lista…”',
          handled: false,
        );
      }

      await shopping.addMany(items);
      return VoiceCommandResult(
        message: 'Adicionei ${items.length} item(ns) na lista.',
      );
    }

    final homeTask = _tryParseHomeTask(text, normalized);
    if (homeTask != null && homeTasks != null) {
      await homeTasks!.add(
        title: homeTask.title,
        effort: homeTask.effort,
        category: homeTask.category,
        area: homeTask.area,
      );
      return VoiceCommandResult(
        message: 'Adicionei "${homeTask.title}" nas tarefas da casa.',
      );
    }

    final event = _tryParseEvent(text, normalized);
    if (event != null) {
      if (timeline.hasConflict(event)) {
        return const VoiceCommandResult(
          message:
              'Esse horário bate com outro compromisso. Ajuste a fala e tente de novo.',
          handled: false,
        );
      }
      await timeline.add(event);
      return VoiceCommandResult(
        message: 'Evento "${event.title}" criado na agenda.',
      );
    }

    return const VoiceCommandResult(
      message:
          'Ainda não entendi esse comando. Tente compras, agenda, tarefas da casa ou finanças.',
      handled: false,
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
          id: DateTime.now().millisecondsSinceEpoch.toString(),
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
    if (!(normalized.contains('ultimo') || normalized.contains('último'))) {
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

  Future<VoiceCommandResult?> _tryFinanceRemove(String normalized) async {
    if (!((normalized.contains('remove') ||
            normalized.contains('apaga') ||
            normalized.contains('exclui')) &&
        (normalized.contains('ultimo') || normalized.contains('último')))) {
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

  bool _looksLikeFinance(String text) {
    return text.contains('gastei') ||
        text.contains('gasto') ||
        text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('entrou') ||
        text.contains('entrada') ||
        text.contains('saída') ||
        text.contains('saida') ||
        text.contains('paguei') ||
        text.contains('coloque') ||
        text.contains('coloca') ||
        text.contains('lança') ||
        text.contains('lanca') ||
        text.contains('adiciona') ||
        text.contains('adicionar') ||
        text.contains('pix') ||
        text.contains('crédito') ||
        text.contains('credito') ||
        text.contains('débito') ||
        text.contains('debito') ||
        text.contains('cartão') ||
        text.contains('cartao') ||
        text.contains('reais');
  }

  bool _looksLikeIncome(String text) {
    return text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('caiu') ||
        text.contains('entrou') ||
        text.contains('entrada') ||
        text.contains('salario') ||
        text.contains('salário');
  }

  FinanceEntryType _entryTypeFromText(String text, {required bool isIncome}) {
    return _entryTypeFromTextOrNull(text, isIncome: isIncome) ??
        (isIncome ? FinanceEntryType.transferIn : FinanceEntryType.debit);
  }

  FinanceEntryType? _entryTypeFromTextOrNull(
    String text, {
    required bool isIncome,
  }) {
    if (text.contains('crédito') ||
        text.contains('credito') ||
        text.contains('cartão') ||
        text.contains('cartao')) {
      return FinanceEntryType.credit;
    }
    if (text.contains('débito') || text.contains('debito')) {
      return FinanceEntryType.debit;
    }
    if (text.contains('dinheiro')) {
      return FinanceEntryType.cash;
    }
    if (text.contains('boleto')) {
      return FinanceEntryType.boleto;
    }
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
      return text.contains('entrada') ||
              text.contains('recebi') ||
              text.contains('ganhei')
          ? FinanceSeedData.getCategoryById('other_income')
          : null;
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
      'casa': 'home',
      'curso': 'education',
      'estudo': 'education',
      'faculdade': 'education',
      'escola': 'education',
    };

    for (final entry in map.entries) {
      if (text.contains(entry.key)) {
        return FinanceSeedData.getCategoryById(entry.value);
      }
    }
    return null;
  }

  double? _extractAmount(String text) {
    final patterns = [
      RegExp(r'(\d+[.,]?\d*)\s*reais'),
      RegExp(r'r\$?\s*(\d+[.,]?\d*)'),
      RegExp(r'(\d+[.,]?\d*)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (value != null) return value;
      }
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    final now = DateTime.now();
    if (text.contains('hoje')) return DateTime(now.year, now.month, now.day);
    if (text.contains('ontem')) {
      final d = now.subtract(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }
    if (text.contains('amanha') || text.contains('amanhã')) {
      final d = now.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }

    final slash = RegExp(
      r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?',
    ).firstMatch(text);
    if (slash != null) {
      final day = int.tryParse(slash.group(1)!);
      final month = int.tryParse(slash.group(2)!);
      final yearRaw = slash.group(3);
      if (day != null && month != null) {
        final year = yearRaw == null
            ? now.year
            : (yearRaw.length == 2
                  ? 2000 + int.parse(yearRaw)
                  : int.parse(yearRaw));
        return DateTime(year, month, day);
      }
    }

    final weekdays = <String, int>{
      'segunda': DateTime.monday,
      'terça': DateTime.tuesday,
      'terca': DateTime.tuesday,
      'quarta': DateTime.wednesday,
      'quinta': DateTime.thursday,
      'sexta': DateTime.friday,
      'sabado': DateTime.saturday,
      'sábado': DateTime.saturday,
      'domingo': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (text.contains(entry.key)) {
        final current = now.weekday;
        var delta = entry.value - current;
        if (delta <= 0) delta += 7;
        final d = now.add(Duration(days: delta));
        return DateTime(d.year, d.month, d.day);
      }
    }
    return null;
  }

  DateTime? _extractTimeAnchor(String text, DateTime date) {
    final interval = RegExp(
      r'(?:as|às|a partir das|das)\s*(\d{1,2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (interval != null) {
      final hour = int.tryParse(interval.group(1)!);
      final minute = int.tryParse(interval.group(2) ?? '0');
      if (hour != null && minute != null) {
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    }

    final compact = RegExp(r'(\d{1,2})\s*h(?:oras?)?').firstMatch(text);
    if (compact != null) {
      final hour = int.tryParse(compact.group(1)!);
      if (hour != null) {
        return DateTime(date.year, date.month, date.day, hour);
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
      if (normalized.contains('freela')) {
        return 'Freela';
      }
      return category.name;
    }

    if (normalized.contains('gasolina') || normalized.contains('combust')) {
      return 'Gasolina';
    }
    if (normalized.contains('mercado')) return 'Mercado';
    if (normalized.contains('farmacia') || normalized.contains('farmácia')) {
      return 'Farmácia';
    }
    if (normalized.contains('internet')) return 'Internet';
    if (normalized.contains('aluguel')) return 'Aluguel';
    if (normalized.contains('uber')) return 'Uber';

    return category.name;
  }

  String? _buildUpdateTitle(String normalized, FinanceTransaction last) {
    if (normalized.contains('gasolina')) return 'Gasolina';
    if (normalized.contains('mercado')) return 'Mercado';
    if (normalized.contains('farmacia') || normalized.contains('farmácia'))
      return 'Farmácia';
    if (normalized.contains('internet')) return 'Internet';
    if (normalized.contains('aluguel')) return 'Aluguel';
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
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final action = isIncome ? 'entrada' : 'gasto';
    return '$action de ${_formatMoney(amount)} em "$title"'
        ' (${category.name}, ${entryType.label.toLowerCase()})'
        ' em $day/$month';
  }

  String _formatMoney(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  bool _looksLikeShoppingAdd(String text) {
    return (text.contains('lista') || text.contains('compras')) &&
        (text.contains('coloca') ||
            text.contains('adiciona') ||
            text.contains('bota') ||
            text.contains('por na lista') ||
            text.contains('põe na lista'));
  }

  List<String> _extractShoppingItems(String original) {
    var text = _normalize(original);
    final removals = [
      'na lista de compras',
      'na lista',
      'lista de compras',
      'lista',
      'adiciona',
      'adicionar',
      'coloca',
      'coloque',
      'bota',
      'por',
      'poe',
      'põe',
      'comprar',
    ];
    for (final token in removals) {
      text = text.replaceAll(token, ' ');
    }

    final parts = text
        .split(RegExp(r',| e '))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e[0].toUpperCase() + e.substring(1))
        .toList();

    return parts;
  }

  _ParsedHomeTask? _tryParseHomeTask(String original, String normalized) {
    final isHome =
        normalized.contains('tarefa da casa') ||
        normalized.contains('tarefas da casa') ||
        normalized.contains('em casa') ||
        normalized.contains('afazer de casa') ||
        normalized.contains('lavar') ||
        normalized.contains('limpar') ||
        normalized.contains('organizar') ||
        normalized.contains('consertar');

    if (!isHome) return null;

    var title = original.trim();
    final removals = [
      RegExp(r'(?i)adiciona(r)?'),
      RegExp(r'(?i)coloca(r)?'),
      RegExp(r'(?i)nas tarefas da casa'),
      RegExp(r'(?i)na tarefa da casa'),
      RegExp(r'(?i)em casa'),
    ];
    for (final r in removals) {
      title = title.replaceAll(r, ' ').trim();
    }
    if (title.isEmpty) return null;

    HomeTaskEffort effort = HomeTaskEffort.quick;
    if (normalized.contains('consert') ||
        normalized.contains('trocar') ||
        normalized.contains('vazamento') ||
        normalized.contains('guarda-roupa') ||
        normalized.contains('banheiro')) {
      effort = HomeTaskEffort.major;
    }

    HomeTaskCategory category = HomeTaskCategory.cleaning;
    if (normalized.contains('organiza')) {
      category = HomeTaskCategory.organization;
    } else if (normalized.contains('consert') ||
        normalized.contains('trocar') ||
        normalized.contains('manuten') ||
        normalized.contains('vazamento')) {
      category = HomeTaskCategory.maintenance;
    }

    HomeTaskArea area = HomeTaskArea.wholeHouse;
    if (normalized.contains('cozinha')) area = HomeTaskArea.kitchen;
    if (normalized.contains('banheiro')) area = HomeTaskArea.bathroom;
    if (normalized.contains('quarto')) area = HomeTaskArea.bedroom;
    if (normalized.contains('sala')) area = HomeTaskArea.livingRoom;
    if (normalized.contains('lavanderia')) area = HomeTaskArea.laundry;
    if (normalized.contains('quintal') || normalized.contains('garagem')) {
      area = HomeTaskArea.outdoor;
    }

    return _ParsedHomeTask(
      title: title.trim(),
      effort: effort,
      category: category,
      area: area,
    );
  }

  TimelineBlock? _tryParseEvent(String original, String normalized) {
    final eventIntent =
        normalized.contains('agenda') ||
        normalized.contains('agendar') ||
        normalized.contains('marca') ||
        normalized.contains('marcar') ||
        normalized.contains('cria evento') ||
        normalized.contains('compromisso') ||
        normalized.contains('reuniao') ||
        normalized.contains('reunião');

    if (!eventIntent) return null;

    final date = _extractDate(normalized) ?? DateTime.now();
    final start = _extractTimeAnchor(normalized, date);
    if (start == null) return null;

    final end = _extractEndTime(normalized, start);
    final title = _extractEventTitle(original);
    if (title.isEmpty) return null;

    final type = _guessEventType(normalized);

    return TimelineBlock(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      start: start,
      end: end,
      reminderMinutes: 10,
      repeatType: TimelineRepeatType.none,
    );
  }

  DateTime? _extractEndTime(String text, DateTime start) {
    final match = RegExp(
      r'(?:até|ate)\s*(\d{1,2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (match != null) {
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2) ?? '0');
      if (hour != null && minute != null) {
        return DateTime(start.year, start.month, start.day, hour, minute);
      }
    }
    return start.add(const Duration(hours: 1));
  }

  String _extractEventTitle(String original) {
    var text = original.trim();
    final patterns = [
      RegExp(r'(?i)\bagenda(r)?\b'),
      RegExp(r'(?i)\bmarca(r)?\b'),
      RegExp(r'(?i)\bcria(r)? evento\b'),
      RegExp(r'(?i)\bcompromisso\b'),
    ];
    for (final p in patterns) {
      text = text.replaceAll(p, ' ');
    }
    text = text
        .replaceAll(RegExp(r'(?i)\bamanh[ãa]\b'), ' ')
        .replaceAll(RegExp(r'(?i)\bhoje\b'), ' ')
        .replaceAll(
          RegExp(
            r'(?i)\bsegunda|terca|terça|quarta|quinta|sexta|sabado|sábado|domingo\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'(?i)\bàs?\s*\d{1,2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'(?i)\bdas\s*\d{1,2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'(?i)\bat[eé]\s*\d{1,2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'\d{1,2}/\d{1,2}(?:/\d{2,4})?'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) {
      return 'Compromisso';
    }
    return text[0].toUpperCase() + text.substring(1);
  }

  TimelineBlockType _guessEventType(String text) {
    if (text.contains('treino')) return TimelineBlockType.workout;
    if (text.contains('estudo') || text.contains('aula'))
      return TimelineBlockType.study;
    if (text.contains('consulta') ||
        text.contains('medico') ||
        text.contains('médico')) {
      return TimelineBlockType.health;
    }
    if (text.contains('descanso')) return TimelineBlockType.rest;
    if (text.contains('amigo') ||
        text.contains('familia') ||
        text.contains('família')) {
      return TimelineBlockType.social;
    }
    return TimelineBlockType.event;
  }

  String _normalize(String value) {
    const map = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };

    var out = value.toLowerCase();
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}

class _ParsedHomeTask {
  const _ParsedHomeTask({
    required this.title,
    required this.effort,
    required this.category,
    required this.area,
  });

  final String title;
  final HomeTaskEffort effort;
  final HomeTaskCategory category;
  final HomeTaskArea area;
}
