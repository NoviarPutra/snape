import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/presentation/widgets/chat_input_bar.dart';
import 'package:snape_ui/presentation/widgets/connection_status_banner.dart';
import 'package:snape_ui/presentation/widgets/message_bubble.dart';
import 'package:snape_ui/presentation/state/chat_state.dart';

Widget createTestWrapper(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: child,
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
}
