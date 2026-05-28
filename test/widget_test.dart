import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/core/onboarding/questions.dart';
import 'package:vida_app/features/body_care/body_care_service.dart';
import 'package:vida_app/features/finance/data/local/finance_seed_data.dart';
import 'package:vida_app/features/finance/data/models/finance_entry_type.dart';
import 'package:vida_app/features/finance/data/models/finance_period_type.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction_source.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/finance/presentation/stores/finance_store.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';
import 'package:vida_app/features/home/presentation/tabs/shopping_list_sheet.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/timeline_repository.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';
import 'package:vida_app/features/voice/application/voice_command_router.dart';

class _MemoryTimelineRepository implements TimelineRepository {
  final List<TimelineBlock> items = [];

  @override
  Future<List<TimelineBlock>> loadAll() async => List.of(items);

  @override
  Future<void> saveAll(List<TimelineBlock> items) async {
    this.items
      ..clear()
      ..addAll(items);
  }
}

class _MemoryFinanceRepository implements FinanceRepository {
  _MemoryFinanceRepository([List<FinanceTransaction>? seed])
    : items = [...?seed];

  final List<FinanceTransaction> items;

  @override
  Future<List<FinanceTransaction>> loadAll() async => List.of(items);

  @override
  Future<void> saveAll(List<FinanceTransaction> items) async {
    this.items
      ..clear()
      ..addAll(items);
  }
}

void main() {
  group('onboarding questions', () {
    test('personal and life stages have unique ids', () {
      final ids = [
        ...personalQuestions.map((question) => question.id),
        ...lifeQuestions.map((question) => question.id),
      ];

      expect(ids, isNotEmpty);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every option question has options', () {
      final optionQuestions = [
        ...personalQuestions,
        ...lifeQuestions,
      ].where((question) => question.type == QuestionType.options);

      for (final question in optionQuestions) {
        expect(
          question.options,
          isNotEmpty,
          reason: 'Question ${question.id} should provide selectable options.',
        );
      }
    });
  });

  testWidgets('cancelling a new shopping list dialog does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShoppingListSheet(store: ShoppingListStore(boxName: 'test')),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Nova'));
    await tester.pumpAndSettle();

    expect(find.text('Nova lista'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('body care', () {
    test('entry copyWith can clear optional values', () {
      final entry = BodyCareEntry(
        food: 3,
        training: 2,
        steps: 8000,
        activeMinutes: 40,
        weightKg: 82.5,
        note: 'sono ruim',
        updatedAt: DateTime(2026, 5, 28),
      );

      final cleaned = entry.copyWith(
        steps: null,
        activeMinutes: null,
        weightKg: null,
        note: null,
      );

      expect(cleaned.food, 3);
      expect(cleaned.training, 2);
      expect(cleaned.steps, isNull);
      expect(cleaned.activeMinutes, isNull);
      expect(cleaned.weightKg, isNull);
      expect(cleaned.note, isNull);
    });

    test('profile keeps manual body goals in json', () {
      final profile = BodyCareProfile(
        heightCm: 178,
        targetWeightKg: 82,
        goal: 'Ganhar massa',
        weeklyTrainingGoal: 4,
        dailyWaterGoal: 3,
        dailySleepGoal: 3,
        updatedAt: DateTime(2026, 5, 28),
      );

      final restored = BodyCareProfile.fromJson(profile.toJson());

      expect(restored.heightCm, 178);
      expect(restored.targetWeightKg, 82);
      expect(restored.goal, 'Ganhar massa');
      expect(restored.weeklyTrainingGoal, 4);
      expect(restored.dailyWaterGoal, 3);
      expect(restored.dailySleepGoal, 3);
    });
  });

  group('voice finance commands', () {
    VoiceCommandRouter buildRouter() {
      return VoiceCommandRouter(
        shopping: ShoppingListStore(boxName: 'voice_test'),
        timeline: TimelineStore(repo: _MemoryTimelineRepository()),
      );
    }

    test('understands natural fuel expense after wake word', () async {
      final result = await buildRouter().handle(
        'Jarvis coloquei 50 de combustivel no carro',
      );

      expect(result.requiresConfirmation, isTrue);
      expect(result.message, contains('R\$ 50,00'));
      expect(result.message.toLowerCase(), contains('combust'));
    });

    test('removes value and payment method from expense title', () async {
      final result = await buildRouter().handle(
        'compra de camisa r\$ 50 no débito',
      );

      expect(result.requiresConfirmation, isTrue);
      expect(result.message, contains('R\$ 50,00'));
      expect(result.message, contains('"Camisa"'));
      expect(result.message, isNot(contains('Camisa 50')));
      expect(result.message, isNot(contains('Débito"')));
    });

    test('detects credit installments in finance command', () async {
      final result = await buildRouter().handle(
        'Jarvis passei 300 de mercado no credito em 3 vezes',
      );

      expect(result.requiresConfirmation, isTrue);
      expect(result.message, contains('R\$ 300,00'));
      expect(result.message, contains('3 parcelas'));
    });

    test('saves voice installments as a single parent transaction', () async {
      final repo = _MemoryFinanceRepository();
      final finance = FinanceStore(repository: repo);
      final router = VoiceCommandRouter(
        shopping: ShoppingListStore(boxName: 'voice_test_parent'),
        timeline: TimelineStore(repo: _MemoryTimelineRepository()),
        finance: finance,
      );

      final result = await router.handle(
        'Jarvis passei 300 de mercado no credito nubank em 3 vezes',
      );
      final confirmed = await result.onConfirm!();

      expect(confirmed.handled, isTrue);
      expect(repo.items, hasLength(1));
      expect(repo.items.single.amount, 300);
      expect(repo.items.single.installmentTotal, 3);
      expect(repo.items.single.cardName, 'Nubank');
    });

    test('understands pix income with payer before or after amount', () async {
      final first = await buildRouter().handle('recebi pix 50 reais maiinha');
      final second = await buildRouter().handle('recebi pix mainha 50 reais');

      for (final result in [first, second]) {
        expect(result.requiresConfirmation, isTrue);
        expect(result.message, contains('R\$ 50,00'));
        expect(result.message, contains('"Mainha"'));
        expect(result.message.toLowerCase(), contains('pix recebido'));
      }
    });
  });

  group('voice routing commands', () {
    test('splits natural shopping list items', () async {
      final shopping = ShoppingListStore(
        boxName: 'voice_split_${DateTime.now().microsecondsSinceEpoch}',
      );
      final router = VoiceCommandRouter(
        shopping: shopping,
        timeline: TimelineStore(repo: _MemoryTimelineRepository()),
      );

      final result = await router.handle(
        'adciionar a lista de compra banana ovos e maças',
      );

      expect(result.requiresConfirmation, isTrue);
      expect(result.message, contains('Banana'));
      expect(result.message, contains('Ovos'));
      expect(result.message, contains('Maçãs'));
      expect(result.message, isNot(contains('Banana Ovos')));
    });

    test('understands home task commands', () async {
      final result = await VoiceCommandRouter(
        shopping: ShoppingListStore(boxName: 'voice_home_task'),
        timeline: TimelineStore(repo: _MemoryTimelineRepository()),
        homeTasks: HomeTasksStore(boxName: 'voice_home_task'),
      ).handle('adiciona lavar banheiro nos afazeres');

      expect(result.requiresConfirmation, isTrue);
      expect(result.message, contains('Lavar Banheiro'));
    });

    test('understands event scheduling commands', () async {
      final result = await VoiceCommandRouter(
        shopping: ShoppingListStore(boxName: 'voice_event'),
        timeline: TimelineStore(repo: _MemoryTimelineRepository()),
      ).handle('agenda dentista amanhã às 15');

      expect(result.requiresConfirmation, isTrue);
      expect(result.message, contains('Dentista'));
      expect(result.message, contains('15:00'));
    });
  });

  group('finance projections', () {
    test(
      'projects monthly recurring transactions into current period',
      () async {
        final now = DateTime.now();
        final store = FinanceStore(
          repository: _MemoryFinanceRepository([
            FinanceTransaction(
              id: 'rent',
              title: 'Aluguel',
              amount: 1200,
              date: DateTime(now.year, now.month - 2, 5),
              category: FinanceSeedData.getCategoryById('house_rent'),
              entryType: FinanceEntryType.pixOut,
              source: FinanceTransactionSource.manual,
              isIncome: false,
              isRecurring: true,
              recurringDayOfMonth: 5,
            ),
          ]),
        );

        await store.load();
        store.setPeriod(FinancePeriodType.currentMonth);

        expect(store.periodTransactions, hasLength(1));
        expect(store.periodTransactions.single.isProjection, isTrue);
        expect(store.totalExpense, 1200);
      },
    );

    test('projects credit parent purchase across installments', () async {
      final now = DateTime.now();
      final store = FinanceStore(
        repository: _MemoryFinanceRepository([
          FinanceTransaction(
            id: 'purchase',
            title: 'Mercado',
            amount: 300,
            date: DateTime(now.year, now.month, 10),
            category: FinanceSeedData.getCategoryById('food_market'),
            entryType: FinanceEntryType.credit,
            source: FinanceTransactionSource.manual,
            isIncome: false,
            installmentGroupId: 'purchase',
            installmentIndex: 1,
            installmentTotal: 3,
          ),
        ]),
      );

      await store.load();
      store.setPeriod(FinancePeriodType.currentMonth);

      expect(store.creditTransactions, hasLength(1));
      expect(store.creditTransactions.single.amount, 100);
      expect(store.creditTransactions.single.isProjection, isTrue);
      expect(store.totalCreditExpense, 100);
    });
  });
}
