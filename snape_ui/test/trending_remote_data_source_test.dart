import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snape_ui/data/datasources/trending_remote_data_source.dart';
import 'package:snape_ui/data/repositories/trending_repository_impl.dart';

void main() {
  group('TrendingRemoteDataSource & Repository', () {
    test('getArticles parses list of articles correctly', () async {
      final mockData = [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'category': 'politics',
          'title': 'Global Climate Summit 2026',
          'summary': '- Nations agree on new targets\nWhy It\'s Trending: Historic pact signed',
          'source_url': 'https://example.com/climate',
          'published_at': '2026-09-03T00:00:00Z',
          'tags': ['climate', 'global'],
          'metadata': {'views': 5000},
          'created_at': '2026-09-03T00:00:00Z',
        }
      ];

      final client = MockClient((request) async {
        expect(request.url.path, contains('/trending'));
        return http.Response(json.encode(mockData), 200);
      });

      final dataSource = TrendingRemoteDataSource(
        client: client,
        baseHttpUrl: 'http://localhost:8000/api/v1',
      );
      final repo = TrendingRepositoryImpl(remoteDataSource: dataSource);

      final articles = await repo.getArticles(category: 'politics');
      expect(articles.length, equals(1));
      expect(articles.first.id, equals('11111111-1111-1111-1111-111111111111'));
      expect(articles.first.category, equals('politics'));
      expect(articles.first.categoryDisplayName, equals('Politics'));
      expect(articles.first.tags, contains('climate'));
    });

    test('getArticle fetches single article by id', () async {
      final mockArticle = {
        'id': '22222222-2222-2222-2222-222222222222',
        'category': 'music',
        'title': 'Grammy Awards Breakthrough',
        'summary': 'New artist sweeps indie charts.',
        'source_url': 'https://example.com/music',
        'published_at': '2026-09-03T00:00:00Z',
        'tags': ['music', 'awards'],
        'metadata': {},
        'created_at': '2026-09-03T00:00:00Z',
      };

      final client = MockClient((request) async {
        expect(request.url.path, contains('/trending/22222222-2222-2222-2222-222222222222'));
        return http.Response(json.encode(mockArticle), 200);
      });

      final dataSource = TrendingRemoteDataSource(
        client: client,
        baseHttpUrl: 'http://localhost:8000/api/v1',
      );
      final repo = TrendingRepositoryImpl(remoteDataSource: dataSource);

      final article = await repo.getArticle('22222222-2222-2222-2222-222222222222');
      expect(article.title, equals('Grammy Awards Breakthrough'));
      expect(article.category, equals('music'));
    });

    test('syncArticles sends post request and returns sync summary', () async {
      final mockSyncResponse = {
        'status': 'success',
        'synced_count': 4,
        'categories': ['politics', 'music'],
        'errors': [],
      };

      final client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, contains('/trending/sync'));
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['limit_per_category'], equals(5));
        return http.Response(json.encode(mockSyncResponse), 200);
      });

      final dataSource = TrendingRemoteDataSource(
        client: client,
        baseHttpUrl: 'http://localhost:8000/api/v1',
      );
      final repo = TrendingRepositoryImpl(remoteDataSource: dataSource);

      final result = await repo.syncArticles(limitPerCategory: 5);
      expect(result.status, equals('success'));
      expect(result.syncedCount, equals(4));
    });

    test('throws exception on non-200 responses', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final dataSource = TrendingRemoteDataSource(
        client: client,
        baseHttpUrl: 'http://localhost:8000/api/v1',
      );
      final repo = TrendingRepositoryImpl(remoteDataSource: dataSource);

      expect(() => repo.getArticles(), throwsException);
      expect(() => repo.syncArticles(), throwsException);
    });
  });
}
