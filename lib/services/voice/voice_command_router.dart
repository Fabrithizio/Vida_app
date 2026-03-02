import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

class VoiceCommandResult {
  const VoiceCommandResult({required this.message, this.handled = true});
  final String message;
  final bool handled;
}

class VoiceCommandRouter {
  VoiceCommandRouter({required this.shopping, required this.timeline});

  final ShoppingListStore shopping;
  final TimelineStore timeline;

  Future<VoiceCommandResult> handle(String transcript) async {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const VoiceCommandResult(
        message: 'Não entendi. Tente de novo.',
        handled: false,
      );
    }

    // 1) COMPRAS
    if (_looksLikeShoppingAdd(text)) {
      final items = _extractShoppingItems(text);
      if (items.isEmpty) {
        return const VoiceCommandResult(
          message: 'Fale os itens após “adicionar na lista …”',
          handled: false,
        );
      }
      await shopping.addMany(items);
      return VoiceCommandResult(
        message: 'Adicionei ${items.length} item(ns) na lista.',
      );
    }

    // 2) EVENTOS / COMPROMISSOS
    final event = _tryParseEvent(text);
    if (event != null) {
      if (timeline.hasConflict(event)) {
        return const VoiceCommandResult(
          message: 'Conflito: já existe algo nesse horário.',
          handled: false,
        );
      }
      await timeline.add(event);
      return VoiceCommandResult(
        message:
            'Evento criado: "${event.title}" em ${_formatPtBr(event.start)}',
      );
    }

    return const VoiceCommandResult(
      message:
          'Comando não reconhecido.\n'
          'Ex: “adicionar na lista ovos, banana, pão”\n'
          'Ex: “agendar evento aniversário dia 23/03 às 10:00”',
      handled: false,
    );
  }

  // -----------------
  // COMPRAS
  // -----------------
  bool _looksLikeShoppingAdd(String t) {
    final s = t.toLowerCase();
    return s.startsWith('adicionar na lista') ||
        s.startsWith('adiciona na lista') ||
        s.startsWith('colocar na lista') ||
        s.startsWith('lista de compras') ||
        s.startsWith('adicionar lista de compras') ||
        s.startsWith('adiciona lista de compras');
  }

  List<String> _extractShoppingItems(String t) {
    var s = t.toLowerCase().trim();

    for (final prefix in [
      'adicionar lista de compras',
      'adiciona lista de compras',
      'adicionar na lista',
      'adiciona na lista',
      'colocar na lista',
      'lista de compras',
    ]) {
      if (s.startsWith(prefix)) {
        s = s.substring(prefix.length).trim();
        break;
      }
    }

    s = s.replaceAll(' e ', ',');
    s = s.replaceAll(' mais ', ',');
    s = s.replaceAll(';', ',');
    s = s.replaceAll('|', ',');

    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // -----------------
  // EVENTOS
  // -----------------
  TimelineBlock? _tryParseEvent(String t) {
    final s = t.trim();
    final lower = s.toLowerCase();

    final isEvent =
        lower.startsWith('agendar') ||
        lower.startsWith('marcar') ||
        lower.startsWith('criar evento') ||
        lower.startsWith('evento') ||
        lower.startsWith('compromisso');

    if (!isEvent) return null;

    final dateMatch = RegExp(
      r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?',
    ).firstMatch(lower);
    if (dateMatch == null) return null;

    final day = int.tryParse(dateMatch.group(1)!) ?? 0;
    final month = int.tryParse(dateMatch.group(2)!) ?? 0;
    final yearRaw = dateMatch.group(3);

    final now = DateTime.now();
    final year = (yearRaw == null || yearRaw.isEmpty)
        ? now.year
        : (yearRaw.length == 2
              ? (2000 + (int.tryParse(yearRaw) ?? now.year % 100))
              : (int.tryParse(yearRaw) ?? now.year));

    int? hour;
    int? minute;

    final hm = RegExp(r'(\d{1,2})\s*[:h]\s*(\d{2})').firstMatch(lower);
    if (hm != null) {
      hour = int.tryParse(hm.group(1)!);
      minute = int.tryParse(hm.group(2)!);
    } else {
      final hOnly = RegExp(r'\b(\d{1,2})\s*(?:h\b|horas?\b)').firstMatch(lower);
      if (hOnly != null) {
        hour = int.tryParse(hOnly.group(1)!);
        minute = 0;
      }
    }
    if (hour == null || minute == null) return null;

    final start = DateTime(year, month, day, hour, minute);

    var title = s;
    for (final prefix in [
      'agendar evento',
      'agendar compromisso',
      'agendar',
      'marcar evento',
      'marcar compromisso',
      'marcar',
      'criar evento',
      'evento',
      'compromisso',
    ]) {
      final p = RegExp('^' + RegExp.escape(prefix), caseSensitive: false);
      title = title.replaceFirst(p, '').trim();
      if (title != s) break;
    }

    title = title
        .replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b'), '')
        .trim();
    title = title.replaceAll(RegExp(r'\b\d{1,2}\s*[:h]\s*\d{2}\b'), '').trim();
    title = title
        .replaceAll(RegExp(r'\b\d{1,2}\s*(?:h\b|horas?\b)\b'), '')
        .trim();
    title = title
        .replaceAll(
          RegExp(r'\bàs\b|\bas\b|\bde\b|\bdia\b', caseSensitive: false),
          ' ',
        )
        .trim();
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (title.isEmpty) title = 'Evento';

    final end = start.add(const Duration(hours: 1));

    return TimelineBlock(
      id: 'v_${DateTime.now().microsecondsSinceEpoch}',
      type: TimelineBlockType.event,
      title: title,
      start: start,
      end: end,
    );
  }

  String _formatPtBr(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$mi';
  }
}
