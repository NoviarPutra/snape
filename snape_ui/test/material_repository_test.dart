import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snape_ui/data/datasources/material_remote_data_source.dart';
import 'package:snape_ui/data/repositories/material_repository_impl.dart';

void main() {
  group('MaterialRemoteDataSource and MaterialRepositoryImpl', () {
    test('getMaterial returns markdown content string on 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/materials/english_b2/cheatsheet') {
          return http.Response(
            json.encode({
              'content': '# B2 Cheatsheet\n- Point 1\n- Point 2',
              'space_slug': 'english_b2',
              'category': 'cheatsheet',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final dataSource = MaterialRemoteDataSource(
        client: mockClient,
        baseHttpUrl: 'http://localhost:8000/api/v1',
      );
      final repo = MaterialRepositoryImpl(remoteDataSource: dataSource);

      final content = await repo.getMaterial('english_b2', 'cheatsheet');
      expect(content, '# B2 Cheatsheet\n- Point 1\n- Point 2');
    });

    test('getMaterial returns null when backend returns 404 (empty/not available)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'detail': 'Material not yet available'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource = MaterialRemoteDataSource(
        client: mockClient,
        baseHttpUrl: 'http://localhost:8000/api/v1',
      );
      final repo = MaterialRepositoryImpl(remoteDataSource: dataSource);

      final content = await repo.getMaterial('english_a1', 'slang');
      expect(content, isNull);
    });

    test('getMaterial throws Exception on non-200 non-404 status (e.g. 500)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final dataSource = MaterialRemoteDataSource(
        client: mockClient,
        baseHttpUrl: 'http://localhost:8000/api/v1',
      );
      final repo = MaterialRepositoryImpl(remoteDataSource: dataSource);

      expect(
        () => repo.getMaterial('english_b2', 'cheatsheet'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
