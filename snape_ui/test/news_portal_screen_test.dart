import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/data/datasources/trending_remote_data_source.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/models/space.dart';
import 'package:snape_ui/domain/models/trending_article.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/domain/repositories/space_repository.dart';
import 'package:snape_ui/domain/repositories/trending_repository.dart';
import 'package:snape_ui/presentation/screens/chat_screen.dart';
import 'package:snape_ui/presentation/screens/news_portal_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';

class MockTrendingRepository implements TrendingRepository {
  List<TrendingArticleModel> articles = [];
  bool shouldThrow = false;
  int syncCallCount = 0;

  @override
  Future<List<TrendingArticleModel>> getArticles({
    String? category,
    int? limit,
  }) async {
    if (shouldThrow) throw Exception('API Error');
    if (category != null && category.isNotEmpty) {
      return articles.where((a) => a.category == category).toList();
    }
    return articles;
  }

  @override
  Future<TrendingArticleModel> getArticle(String id) async {
    if (shouldThrow) throw Exception('API Error');
    return articles.firstWhere((a) => a.id == id);
  }

  @override
  Future<TrendingSyncResult> syncArticles({
    String? category,
    int limitPerCategory = 5,
  }) async {
    if (shouldThrow) throw Exception('Sync Error');
    syncCallCount++;
    return const TrendingSyncResult(
      status: 'success',
      syncedCount: 3,
      categories: ['politics', 'music'],
      errors: [],
    );
  }
}

class MockChatRepo implements ChatRepository {
  List<SessionModel> sessions = [];
  int createSessionCallCount = 0;

  final StreamController<WSOutputEvent> _eventController =
      StreamController<WSOutputEvent>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _connected = false;

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) async => sessions;

  @override
  Future<SessionModel> createSession({
    String title = 'Casual English Chat',
    String spaceSlug = 'english_b2',
  }) async {
    createSessionCallCount++;
    final session = SessionModel(
      id: 'session-${sessions.length + 1}',
      title: title,
      spaceSlug: spaceSlug,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    sessions.add(session);
    return session;
  }

  @override
  Future<SessionModel> updateSessionTitle(String sessionId, String title) async {
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    final updated = sessions[idx].copyWith(title: title);
    sessions[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async => [];

  @override
  Future<void> connectToChatStream(String sessionId) async {
    _connected = true;
    _connectionController.add(true);
  }

  @override
  Future<void> disconnectStream() async {
    _connected = false;
    _connectionController.add(false);
  }

  @override
  void sendChatMessage(String content) {}

  @override
  Future<Uint8List> synthesizeAudio(String text) async => Uint8List(0);

  @override
  Stream<WSOutputEvent> get chatEvents => _eventController.stream;

  @override
  Stream<bool> get connectionStatus => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  @override
  void dispose() {
    _eventController.close();
    _connectionController.close();
  }
}

class MockSpaceRepo implements SpaceRepository {
  @override
  Future<List<SpaceModel>> getSpaces() async {
    return [
      const SpaceModel(
        slug: 'english_b2',
        displayName: 'B2 – Conversational',
        cefrLevel: 'b2',
        voiceCallEnabled: true,
        ttsEnabled: true,
      ),
      const SpaceModel(
        slug: 'tech',
        displayName: 'Teknologi',
        cefrLevel: null,
        voiceCallEnabled: false,
        ttsEnabled: false,
      ),
    ];
  }
}

Widget createNewsPortalApp({
  required MockTrendingRepository trendingRepo,
  required MockChatRepo chatRepo,
  required MockSpaceRepo spaceRepo,
}) {
  return ProviderScope(
    overrides: [
      trendingRepositoryProvider.overrideWithValue(trendingRepo),
      chatRepositoryProvider.overrideWithValue(chatRepo),
      spaceRepositoryProvider.overrideWithValue(spaceRepo),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: const NewsPortalScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleArticles = [
    TrendingArticleModel(
      id: 'art-1',
      category: 'politics',
      title: 'Global Carbon Tax Policy Adopted',
      summary: '- Global delegates agree on tax rates.\nWhy It\'s Trending: Unprecedented policy change.',
      sourceUrl: 'https://example.com/carbon',
      publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
      tags: const ['carbon', 'tax'],
      metadata: const {},
      createdAt: DateTime.now(),
    ),
    TrendingArticleModel(
      id: 'art-2',
      category: 'music',
      title: 'Legendary Band Drops Surprise Album',
      summary: '- Recorded entirely in analog.\nWhy It\'s Trending: First release in 15 years.',
      sourceUrl: 'https://example.com/album',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      tags: const ['music', 'album'],
      metadata: const {},
      createdAt: DateTime.now(),
    ),
  ];

  testWidgets('NewsPortalScreen renders category chips and article list', (tester) async {
    final trendingRepo = MockTrendingRepository()..articles = sampleArticles;
    final chatRepo = MockChatRepo();
    final spaceRepo = MockSpaceRepo();

    await tester.pumpWidget(
      createNewsPortalApp(
        trendingRepo: trendingRepo,
        chatRepo: chatRepo,
        spaceRepo: spaceRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('News & Trends'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Politics'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Global Carbon Tax Policy Adopted'), findsOneWidget);
    expect(find.text('Legendary Band Drops Surprise Album'), findsOneWidget);
  });

  testWidgets('Selecting category chip filters the visible articles', (tester) async {
    final trendingRepo = MockTrendingRepository()..articles = sampleArticles;
    final chatRepo = MockChatRepo();
    final spaceRepo = MockSpaceRepo();

    await tester.pumpWidget(
      createNewsPortalApp(
        trendingRepo: trendingRepo,
        chatRepo: chatRepo,
        spaceRepo: spaceRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Politics'));
    await tester.pumpAndSettle();

    expect(find.text('Global Carbon Tax Policy Adopted'), findsOneWidget);
    expect(find.text('Legendary Band Drops Surprise Album'), findsNothing);
  });

  testWidgets('Clicking Bahas (English) creates session and navigates to ChatScreen with preloaded prompt',
      (tester) async {
    final trendingRepo = MockTrendingRepository()..articles = sampleArticles;
    final chatRepo = MockChatRepo();
    final spaceRepo = MockSpaceRepo();

    await tester.pumpWidget(
      createNewsPortalApp(
        trendingRepo: trendingRepo,
        chatRepo: chatRepo,
        spaceRepo: spaceRepo,
      ),
    );
    await tester.pumpAndSettle();

    final englishBtn = find.text('Bahas (English)').first;
    await tester.tap(englishBtn);
    await tester.pumpAndSettle();

    expect(chatRepo.createSessionCallCount, equals(1));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.textContaining('Global Carbon Tax Policy Adopted'), findsWidgets);
  });

  testWidgets('Clicking Diskusi Santai creates session and navigates with Indonesian prompt',
      (tester) async {
    final trendingRepo = MockTrendingRepository()..articles = sampleArticles;
    final chatRepo = MockChatRepo();
    final spaceRepo = MockSpaceRepo();

    await tester.pumpWidget(
      createNewsPortalApp(
        trendingRepo: trendingRepo,
        chatRepo: chatRepo,
        spaceRepo: spaceRepo,
      ),
    );
    await tester.pumpAndSettle();

    final idBtn = find.text('Diskusi Santai').first;
    await tester.tap(idBtn);
    await tester.pumpAndSettle();

    expect(chatRepo.createSessionCallCount, equals(1));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.textContaining('Yuk kita bahas santai berita trending ini'), findsWidgets);
  });
}
