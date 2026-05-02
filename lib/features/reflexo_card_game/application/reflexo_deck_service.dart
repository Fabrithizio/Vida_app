// ============================================================================
// FILE: lib/features/reflexo_card_game/application/reflexo_deck_service.dart
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reflexo_content.dart';
import '../domain/reflexo_models.dart';

class ReflexoDeckService {
  const ReflexoDeckService._();

  static const _deckKey = 'reflexo_card_game_custom_deck_ids_v1';
  static const _templateKey = 'reflexo_card_game_template_id_v1';

  static Future<List<String>> loadDeckIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_deckKey);
    if (ids != null && ReflexoContent.validateDeckIds(ids).isValid) {
      return ids;
    }
    final templateId = prefs.getString(_templateKey);
    final template = ReflexoContent.starterDecks.firstWhere(
      (deck) => deck.id == templateId,
      orElse: () => ReflexoContent.defaultDeck,
    );
    return template.cardIds;
  }

  static Future<ReflexoDeckTemplate> loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final templateId = prefs.getString(_templateKey);
    return ReflexoContent.starterDecks.firstWhere(
      (deck) => deck.id == templateId,
      orElse: () => ReflexoContent.defaultDeck,
    );
  }

  static Future<void> saveTemplate(ReflexoDeckTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_templateKey, template.id);
    await prefs.setStringList(_deckKey, template.cardIds);
  }

  static Future<void> saveCustomDeck(List<String> ids) async {
    final validation = ReflexoContent.validateDeckIds(ids);
    if (!validation.isValid) {
      throw StateError(validation.messages.join('\n'));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deckKey, ids);
  }

  static ReflexoDeckValidation validate(List<String> ids) {
    return ReflexoContent.validateDeckIds(ids);
  }
}
