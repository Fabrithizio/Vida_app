// ============================================================================
// FILE: lib/features/voice/application/voice_command_router.dart
//
// O que faz:
// - interpreta comandos de voz em português mais natural
// - cria eventos na timeline com data/hora mais flexíveis
// - adiciona itens na lista de compras
// - adiciona tarefas da casa
// ============================================================================

import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

class VoiceCommandResult {
  const VoiceCommandResult({required this.message, this.handled = true});

  final String message;
  final bool handled;
}

class VoiceCommandRouter {
  VoiceCommandRouter({
    required this.shopping,
    required this.timeline,
    required this.homeTasks,
  });

  final ShoppingListStore shopping;
  final TimelineStore timeline;
  final HomeTasksStore homeTasks;

  Future<VoiceCommandResult> handle(String transcript) async {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const VoiceCommandResult(
        message: 'Não entendi nada. Tenta falar de novo.',
        handled: false,
      );
    }

    if (_looksLikeShoppingAdd(text)) {
      final items = _extractShoppingItems(text);
      if (items.isEmpty) {
        return const VoiceCommandResult(
          message: 'Fala os itens que você quer colocar na lista.',
          handled: false,
        );
      }
      await shopping.addMany(items);
      return VoiceCommandResult(
        message:
            'Beleza. Coloquei ${items.length} item(ns) na lista de compras.',
      );
    }

    if (_looksLikeHomeTaskAdd(text)) {
      final tasks = _extractHomeTasks(text);
      if (tasks.isEmpty) {
        return const VoiceCommandResult(
          message: 'Me diga a tarefa da casa que você quer adicionar.',
          handled: false,
        );
      }

      for (final taskTitle in tasks) {
        await homeTasks.add(
          title: _capitalize(taskTitle),
          effort: _guessHomeTaskEffort(taskTitle),
          category: _guessHomeTaskCategory(taskTitle),
          area: _guessHomeTaskArea(taskTitle),
        );
      }

      return VoiceCommandResult(
        message: tasks.length == 1
            ? 'Certo. Adicionei a tarefa da casa "${_capitalize(tasks.first)}".'
            : 'Certo. Adicionei ${tasks.length} tarefas da casa.',
      );
    }

    final eventDraft = _tryParseEventDraft(text);
    if (eventDraft.looksLikeEvent) {
      if (eventDraft.missingDate) {
        return const VoiceCommandResult(
          message:
              'Entendi que você quer agendar algo, mas faltou a data. Exemplo: “agenda treino amanhã às 7”.',
          handled: false,
        );
      }
      if (eventDraft.missingStartTime) {
        return const VoiceCommandResult(
          message:
              'Entendi o evento, mas faltou o horário. Exemplo: “agenda dentista amanhã às 15”.',
          handled: false,
        );
      }

      final block = eventDraft.toBlock();
      if (block == null) {
        return const VoiceCommandResult(
          message:
              'Não consegui montar esse evento. Tenta falar de outro jeito.',
          handled: false,
        );
      }

      if (timeline.hasConflict(block)) {
        return VoiceCommandResult(
          message:
              'Tem conflito nesse horário com outro evento. ${_formatEvent(block)}',
          handled: false,
        );
      }

      await timeline.add(block);
      return VoiceCommandResult(message: 'Feito. ${_formatEvent(block)}');
    }

    return const VoiceCommandResult(
      message:
          'Ainda não entendi esse comando.\n'
          'Ex: “agenda treino amanhã às 7 até 8”\n'
          'Ex: “coloca arroz, leite e ovos na lista”\n'
          'Ex: “adiciona lavar banheiro nas tarefas da casa”',
      handled: false,
    );
  }

  bool _looksLikeShoppingAdd(String text) {
    final s = _norm(text);
    final startsWithAction = RegExp(
      r'^(adicionar|adiciona|colocar|coloca|botar|bota|por|poe|põe|incluir|inclui|anotar|anota)\b',
    ).hasMatch(s);
    return (startsWithAction &&
            (s.contains('lista') || s.contains('compras'))) ||
        s.startsWith('lista de compras') ||
        s.startsWith('lista ');
  }

  List<String> _extractShoppingItems(String text) {
    var s = _norm(text);

    final suffix = RegExp(
      r'^(?:adicionar|adiciona|colocar|coloca|botar|bota|por|poe|põe|incluir|inclui|anotar|anota)\s+(.+?)\s+(?:na|no)\s+lista(?:\s+de\s+compras)?$',
    ).firstMatch(s);
    if (suffix != null) {
      return _splitNaturalList(suffix.group(1)!);
    }

    for (final prefix in [
      'adicionar lista de compras',
      'adiciona lista de compras',
      'adicionar na lista de compras',
      'adiciona na lista de compras',
      'colocar na lista de compras',
      'coloca na lista de compras',
      'botar na lista de compras',
      'bota na lista de compras',
      'adicionar na lista',
      'adiciona na lista',
      'colocar na lista',
      'coloca na lista',
      'botar na lista',
      'bota na lista',
      'lista de compras',
      'lista',
    ]) {
      if (s.startsWith(prefix)) {
        s = s.substring(prefix.length).trim();
        return _splitNaturalList(s);
      }
    }

    return const [];
  }

  bool _looksLikeHomeTaskAdd(String text) {
    final s = _norm(text);
    final startsWithAction = RegExp(
      r'^(adicionar|adiciona|colocar|coloca|botar|bota|por|poe|põe|anotar|anota|criar|cria)\b',
    ).hasMatch(s);
    return startsWithAction &&
        (s.contains('tarefas da casa') ||
            s.contains('afazeres da casa') ||
            s.contains('tarefas de casa') ||
            s.contains('afazeres de casa') ||
            s.contains('em casa'));
  }

  List<String> _extractHomeTasks(String text) {
    var s = _norm(text);

    final suffix = RegExp(
      r'^(?:adicionar|adiciona|colocar|coloca|botar|bota|por|poe|põe|anotar|anota|criar|cria)\s+(.+?)\s+(?:nas|nos|na|no)\s+(?:tarefas|afazeres)(?:\s+da\s+casa|\s+de\s+casa)?$',
    ).firstMatch(s);
    if (suffix != null) {
      return _splitNaturalList(suffix.group(1)!);
    }

    for (final prefix in [
      'adicionar nas tarefas da casa',
      'adiciona nas tarefas da casa',
      'adicionar nos afazeres da casa',
      'adiciona nos afazeres da casa',
      'adicionar tarefa da casa',
      'adiciona tarefa da casa',
      'adicionar afazer da casa',
      'adiciona afazer da casa',
      'tarefas da casa',
      'afazeres da casa',
      'tarefas de casa',
      'afazeres de casa',
    ]) {
      if (s.startsWith(prefix)) {
        s = s.substring(prefix.length).trim();
        return _splitNaturalList(s);
      }
    }

    final afterEmCasa = RegExp(
      r'^(?:adicionar|adiciona|colocar|coloca|botar|bota|por|poe|põe|anotar|anota|criar|cria)\s+(.+?)\s+em\s+casa$',
    ).firstMatch(s);
    if (afterEmCasa != null) {
      return _splitNaturalList(afterEmCasa.group(1)!);
    }

    return const [];
  }

  _ParsedEventDraft _tryParseEventDraft(String transcript) {
    final original = transcript.trim();
    final s = _norm(original);

    final looksLikeEvent =
        RegExp(
          r'^(agendar|agenda|marcar|marca|criar evento|cria evento|evento|compromisso|lembrete|colocar na agenda|coloca na agenda|por na agenda|põe na agenda|poe na agenda)\b',
        ).hasMatch(s) ||
        s.contains(' na agenda ');

    if (!looksLikeEvent) {
      return const _ParsedEventDraft(looksLikeEvent: false);
    }

    final parsedDate = _parseDateFromText(s);
    final parsedTime = _parseTimeRangeFromText(s);
    final title = _cleanupEventTitle(original);

    return _ParsedEventDraft(
      looksLikeEvent: true,
      title: title.isEmpty ? 'Evento' : title,
      date: parsedDate,
      startHour: parsedTime?.startHour,
      startMinute: parsedTime?.startMinute,
      endHour: parsedTime?.endHour,
      endMinute: parsedTime?.endMinute,
      missingDate: parsedDate == null,
      missingStartTime: parsedTime == null,
    );
  }

  HomeTaskEffort _guessHomeTaskEffort(String title) {
    final s = _norm(title);
    if (RegExp(
      r'(consertar|trocar|instalar|resolver|pintar|reformar|vazamento|montar|desmontar|faxina|limpeza pesada)',
    ).hasMatch(s)) {
      return HomeTaskEffort.major;
    }
    return HomeTaskEffort.quick;
  }

  HomeTaskCategory _guessHomeTaskCategory(String title) {
    final s = _norm(title);
    if (RegExp(
      r'(consertar|trocar|instalar|vazamento|manutencao)',
    ).hasMatch(s)) {
      return HomeTaskCategory.maintenance;
    }
    if (RegExp(r'(organizar|guardar|arrumar|dobrar|separar)').hasMatch(s)) {
      return HomeTaskCategory.organization;
    }
    return HomeTaskCategory.cleaning;
  }

  HomeTaskArea _guessHomeTaskArea(String title) {
    final s = _norm(title);
    if (s.contains('banheiro')) return HomeTaskArea.bathroom;
    if (s.contains('cozinha') || s.contains('pia')) return HomeTaskArea.kitchen;
    if (s.contains('quarto') ||
        s.contains('cama') ||
        s.contains('guarda roupa')) {
      return HomeTaskArea.bedroom;
    }
    if (s.contains('sala')) return HomeTaskArea.livingRoom;
    if (s.contains('lavanderia') || s.contains('roupa'))
      return HomeTaskArea.laundry;
    if (s.contains('quintal') ||
        s.contains('garagem') ||
        s.contains('jardim') ||
        s.contains('area externa')) {
      return HomeTaskArea.outdoor;
    }
    if (s.contains('casa toda')) return HomeTaskArea.wholeHouse;
    return HomeTaskArea.other;
  }

  _ParsedDate? _parseDateFromText(String s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dm = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b').firstMatch(s);
    if (dm != null) {
      final day = int.tryParse(dm.group(1)!);
      final month = int.tryParse(dm.group(2)!);
      final yearRaw = dm.group(3);
      if (day != null && month != null) {
        final year = (yearRaw == null || yearRaw.isEmpty)
            ? now.year
            : (yearRaw.length == 2
                  ? 2000 + (int.tryParse(yearRaw) ?? 0)
                  : (int.tryParse(yearRaw) ?? now.year));
        return _ParsedDate(DateTime(year, month, day));
      }
    }

    if (s.contains('depois de amanha')) {
      return _ParsedDate(today.add(const Duration(days: 2)));
    }
    if (RegExp(r'\bamanha\b').hasMatch(s)) {
      return _ParsedDate(today.add(const Duration(days: 1)));
    }
    if (RegExp(r'\bhoje\b').hasMatch(s)) {
      return _ParsedDate(today);
    }

    for (final entry in _weekdayMap.entries) {
      final pattern = RegExp('\\b${RegExp.escape(entry.key)}\\b');
      if (pattern.hasMatch(s)) {
        return _ParsedDate(_nextWeekday(today, entry.value));
      }
    }

    return null;
  }

  _ParsedTimeRange? _parseTimeRangeFromText(String s) {
    final normalized = s.replaceAll(' às ', ' as ').replaceAll(' à ', ' a ');

    final range = RegExp(
      r'\bdas\s+(\d{1,2})(?::(\d{2}))?\s*(?:h|horas?)?(\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?\s+(?:as|a|ate|até)\s+(\d{1,2})(?::(\d{2}))?\s*(?:h|horas?)?(\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?',
    ).firstMatch(normalized);
    if (range != null) {
      return _ParsedTimeRange(
        startHour: _applyDayPeriod(
          int.parse(range.group(1)!),
          range.group(3) ?? range.group(0)!,
        ),
        startMinute: int.tryParse(range.group(2) ?? '') ?? 0,
        endHour: _applyDayPeriod(
          int.parse(range.group(4)!),
          range.group(6) ?? range.group(0)!,
        ),
        endMinute: int.tryParse(range.group(5) ?? '') ?? 0,
      );
    }

    final single = RegExp(
      r'\b(?:as|a)\s*(\d{1,2})(?::(\d{2}))?\s*(?:h|horas?)?(\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?(?:\s+(?:ate|até)\s+(\d{1,2})(?::(\d{2}))?\s*(?:h|horas?)?(\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?)?',
    ).firstMatch(normalized);
    if (single != null) {
      return _ParsedTimeRange(
        startHour: _applyDayPeriod(
          int.parse(single.group(1)!),
          single.group(3) ?? single.group(0)!,
        ),
        startMinute: int.tryParse(single.group(2) ?? '') ?? 0,
        endHour: single.group(4) != null
            ? _applyDayPeriod(
                int.parse(single.group(4)!),
                single.group(6) ?? single.group(0)!,
              )
            : null,
        endMinute: single.group(5) != null
            ? int.tryParse(single.group(5)!) ?? 0
            : null,
      );
    }

    final informal = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(?:h|horas?)?(\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)\b',
    ).firstMatch(normalized);
    if (informal != null) {
      return _ParsedTimeRange(
        startHour: _applyDayPeriod(
          int.parse(informal.group(1)!),
          informal.group(3)!,
        ),
        startMinute: int.tryParse(informal.group(2) ?? '') ?? 0,
      );
    }

    final shortOnly = RegExp(
      r'\b(\d{1,2})\s*(?:h|horas?)\b',
    ).firstMatch(normalized);
    if (shortOnly != null) {
      return _ParsedTimeRange(
        startHour: int.parse(shortOnly.group(1)!).clamp(0, 23),
        startMinute: 0,
      );
    }

    return null;
  }

  int _applyDayPeriod(int hour, String context) {
    final s = _norm(context);
    var value = hour;

    if (s.contains('da tarde') || s.contains('da noite')) {
      if (value < 12) value += 12;
    } else if (s.contains('da madrugada') || s.contains('da manha')) {
      if (value == 12) value = 0;
    }

    return value.clamp(0, 23);
  }

  String _cleanupEventTitle(String original) {
    var title = _norm(original);

    for (final prefix in [
      'agendar evento',
      'agenda evento',
      'agendar compromisso',
      'agenda compromisso',
      'agendar',
      'agenda',
      'marcar evento',
      'marca evento',
      'marcar compromisso',
      'marca compromisso',
      'marcar',
      'marca',
      'criar evento',
      'cria evento',
      'evento',
      'compromisso',
      'lembrete',
      'colocar na agenda',
      'coloca na agenda',
      'por na agenda',
      'poe na agenda',
      'põe na agenda',
    ]) {
      if (title.startsWith(prefix)) {
        title = title.substring(prefix.length).trim();
        break;
      }
    }

    title = title.replaceAll(
      RegExp(r'\b(hoje|amanha|depois de amanha)\b'),
      ' ',
    );
    title = title.replaceAll(
      RegExp(
        r'\bsegunda(?: feira)?|terca(?: feira)?|quarta(?: feira)?|quinta(?: feira)?|sexta(?: feira)?|sabado|domingo\b',
      ),
      ' ',
    );
    title = title.replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b'), ' ');
    title = title.replaceAll(
      RegExp(
        r'\bdas\s+\d{1,2}(?::\d{2})?\s*(?:h|horas?)?(?:\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?\s+(?:as|a|ate|até)\s+\d{1,2}(?::\d{2})?\s*(?:h|horas?)?(?:\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?',
      ),
      ' ',
    );
    title = title.replaceAll(
      RegExp(
        r'\b(?:as|a)\s*\d{1,2}(?::\d{2})?\s*(?:h|horas?)?(?:\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?',
      ),
      ' ',
    );
    title = title.replaceAll(
      RegExp(
        r'\b(?:ate|até)\s+\d{1,2}(?::\d{2})?\s*(?:h|horas?)?(?:\s+da\s+manha|\s+da\s+tarde|\s+da\s+noite|\s+da\s+madrugada)?',
      ),
      ' ',
    );
    title = title.replaceAll(RegExp(r'\bdia\b|\bde\b'), ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    return _capitalize(title);
  }

  DateTime _nextWeekday(DateTime today, int weekday) {
    var diff = weekday - today.weekday;
    if (diff <= 0) diff += 7;
    return today.add(Duration(days: diff));
  }

  List<String> _splitNaturalList(String s) {
    return s
        .replaceAll(' e ', ',')
        .replaceAll(' mais ', ',')
        .replaceAll(';', ',')
        .replaceAll('|', ',')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _formatEvent(TimelineBlock block) {
    final start = _formatPtBr(block.start);
    final end = block.end != null ? ' até ${_timeOnly(block.end!)}' : '';
    return 'Agendei "${block.title}" em $start$end.';
  }

  String _formatPtBr(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm às $hh:$mi';
  }

  String _timeOnly(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mi';
  }

  String _capitalize(String text) {
    final s = text.trim();
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _norm(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

const Map<String, int> _weekdayMap = {
  'segunda': DateTime.monday,
  'segunda feira': DateTime.monday,
  'terca': DateTime.tuesday,
  'terca feira': DateTime.tuesday,
  'quarta': DateTime.wednesday,
  'quarta feira': DateTime.wednesday,
  'quinta': DateTime.thursday,
  'quinta feira': DateTime.thursday,
  'sexta': DateTime.friday,
  'sexta feira': DateTime.friday,
  'sabado': DateTime.saturday,
  'domingo': DateTime.sunday,
};

class _ParsedDate {
  const _ParsedDate(this.value);

  final DateTime value;
}

class _ParsedTimeRange {
  const _ParsedTimeRange({
    required this.startHour,
    required this.startMinute,
    this.endHour,
    this.endMinute,
  });

  final int startHour;
  final int startMinute;
  final int? endHour;
  final int? endMinute;
}

class _ParsedEventDraft {
  const _ParsedEventDraft({
    required this.looksLikeEvent,
    this.title = 'Evento',
    this.date,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.missingDate = false,
    this.missingStartTime = false,
  });

  final bool looksLikeEvent;
  final String title;
  final _ParsedDate? date;
  final int? startHour;
  final int? startMinute;
  final int? endHour;
  final int? endMinute;
  final bool missingDate;
  final bool missingStartTime;

  TimelineBlock? toBlock() {
    final d = date?.value;
    if (d == null || startHour == null || startMinute == null) return null;

    final start = DateTime(d.year, d.month, d.day, startHour!, startMinute!);
    DateTime end;
    if (endHour != null) {
      end = DateTime(d.year, d.month, d.day, endHour!, endMinute ?? 0);
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
    } else {
      end = start.add(const Duration(hours: 1));
    }

    return TimelineBlock(
      id: 'voice_${DateTime.now().microsecondsSinceEpoch}',
      type: _guessTimelineType(title),
      title: title.trim().isEmpty ? 'Evento' : title.trim(),
      start: start,
      end: end,
    );
  }

  TimelineBlockType _guessTimelineType(String title) {
    final s = title.toLowerCase();
    if (RegExp(
      r'(treino|academia|correr|corrida|musculacao|musculação|pedalar|bike)',
    ).hasMatch(s)) {
      return TimelineBlockType.workout;
    }
    if (RegExp(r'(estudo|estudar|curso|aula|prova|ler|leitura)').hasMatch(s)) {
      return TimelineBlockType.study;
    }
    if (RegExp(
      r'(medico|médico|dentista|consulta|exame|terapia)',
    ).hasMatch(s)) {
      return TimelineBlockType.health;
    }
    if (RegExp(r'(descanso|dormir|soneca|pausa)').hasMatch(s)) {
      return TimelineBlockType.rest;
    }
    if (RegExp(
      r'(amigo|familia|família|encontro|almoco|almoço|jantar)',
    ).hasMatch(s)) {
      return TimelineBlockType.social;
    }
    return TimelineBlockType.event;
  }
}
