import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/memory_item.dart';
import 'package:snape_ui/domain/repositories/memory_repository.dart';
import 'package:snape_ui/presentation/state/chat_state.dart';
import 'package:snape_ui/presentation/state/providers.dart';
import 'package:snape_ui/presentation/widgets/chat_input_bar.dart';
import 'package:snape_ui/presentation/widgets/connection_status_banner.dart';
import 'package:snape_ui/presentation/widgets/memory_drawer.dart';
import 'package:snape_ui/presentation/widgets/message_bubble.dart';

class FakeMemoryRepository implements MemoryRepository {
  List<MemoryItem> items = [];
  bool throwError = false;

  @override
  Future<List<MemoryItem>> getMemories({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    if (throwError) {
      throw Exception('Failed to load memories');
    }
    if (category != null && category.isNotEmpty) {
      return items
          .where((m) => m.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    return items;
  }

  @override
  Future<void> deleteMemory(String memoryId) async {
    items.removeWhere((m) => m.id == memoryId);
  }
}

Widget createTestWrapper(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  group('MessageBubble Widget', () {
    testWidgets('renders user message bubble', (WidgetTester tester) async {
      final userMessage = ChatMessage(
        id: '1',
        sessionId: 'sess-1',
        role: MessageRole.user,
        content: 'Hello, this is a user message.',
        createdAt: DateTime(2026, 8, 30, 10, 0),
      );

      await tester.pumpWidget(createTestWrapper(MessageBubble(message: userMessage)));
      await tester.pumpAndSettle();

      expect(find.text('Hello, this is a user message.'), findsOneWidget);
      expect(find.text('Snape'), findsNothing);
    });

    testWidgets('renders companion message bubble with badge and streaming indicator',
        (WidgetTester tester) async {
      final companionMessage = ChatMessage(
        id: '2',
        sessionId: 'sess-1',
        role: MessageRole.assistant,
        content: 'I am your English companion.',
        isStreaming: true,
        createdAt: DateTime(2026, 8, 30, 10, 1),
      );

      await tester.pumpWidget(createTestWrapper(MessageBubble(message: companionMessage)));
      await tester.pump();

      expect(find.text('I am your English companion.'), findsOneWidget);
      expect(find.text('Snape'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders memory badge tags when memories are extracted',
        (WidgetTester tester) async {
      final companionMessage = ChatMessage(
        id: '3',
        sessionId: 'sess-1',
        role: MessageRole.assistant,
        content: 'I noted down your study preferences.',
        extractedMemories: ['Prefers IELTS preparation', 'Studies 20 minutes daily'],
        createdAt: DateTime(2026, 8, 30, 10, 2),
      );

      await tester.pumpWidget(createTestWrapper(MessageBubble(message: companionMessage)));
      await tester.pumpAndSettle();

      expect(find.text('Remembered: Prefers IELTS preparation'), findsOneWidget);
      expect(find.text('Remembered: Studies 20 minutes daily'), findsOneWidget);
    });
  });

  group('ChatInputBar Widget', () {
    testWidgets('typing text enables send button and triggers onSendMessage callback',
        (WidgetTester tester) async {
      String? submittedText;

      await tester.pumpWidget(
        createTestWrapper(
          ChatInputBar(
            onSendMessage: (text) {
              submittedText = text;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'Practicing speaking today');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byIcon(Icons.arrow_upward_rounded);
      expect(sendButtonFinder, findsOneWidget);

      await tester.tap(sendButtonFinder);
      await tester.pumpAndSettle();

      expect(submittedText, 'Practicing speaking today');
    });
  });

  group('ConnectionStatusBanner Widget', () {
    testWidgets('shows reconnecting and error states appropriately',
        (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        createTestWrapper(
          ConnectionStatusBanner(
            status: ConnectionStatus.reconnecting,
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reconnecting to stream...'), findsOneWidget);

      await tester.pumpWidget(
        createTestWrapper(
          ConnectionStatusBanner(
            status: ConnectionStatus.disconnected,
            errorMessage: 'Network connection dropped',
            onRetry: () {
              retried = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network connection dropped'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('MemoryDrawer Widget', () {
    testWidgets('renders memory drawer with items and category badges',
        (WidgetTester tester) async {
      final fakeRepo = FakeMemoryRepository()
        ..items = [
          MemoryItem(
            id: 'm1',
            userId: 'u1',
            category: 'goal',
            content: 'Wants to improve English fluency for job interviews',
            createdAt: DateTime(2026, 8, 30, 9, 0),
          ),
          MemoryItem(
            id: 'm2',
            userId: 'u1',
            category: 'preference',
            content: 'Enjoys conversational roleplay',
            createdAt: DateTime(2026, 8, 30, 9, 30),
          ),
        ];

      await tester.pumpWidget(
        createTestWrapper(
          const MemoryDrawer(),
          overrides: [
            memoryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Snape\'s Memory'), findsOneWidget);
      expect(find.text('Wants to improve English fluency for job interviews'), findsOneWidget);
      expect(find.text('Enjoys conversational roleplay'), findsOneWidget);
      expect(find.text('GOAL'), findsWidgets);
      expect(find.text('PREFERENCE'), findsWidgets);
    });

    testWidgets('renders empty state when no memories are stored',
        (WidgetTester tester) async {
      final fakeRepo = FakeMemoryRepository()..items = [];

      await tester.pumpWidget(
        createTestWrapper(
          const MemoryDrawer(),
          overrides: [
            memoryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No memories stored yet'), findsOneWidget);
    });
  });
}
