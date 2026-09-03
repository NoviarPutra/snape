import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snape_ui/data/datasources/user_remote_data_source.dart';
import 'package:snape_ui/data/repositories/user_repository_impl.dart';

void main() {
  group('UserRepositoryImpl and UserRemoteDataSource', () {
    test('getUserProfile returns parsed UserModel on 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/user')) {
          return http.Response(
            json.encode({
              'id': '123e4567-e89b-12d3-a456-426614174000',
              'username': 'learner_1',
              'full_name': 'Test Learner',
              'native_language': 'Indonesian',
              'english_level': 'Intermediate',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final dataSource = UserRemoteDataSource(
        client: mockClient,
        userUrl: 'http://localhost:8000/api/v1/user',
      );
      final repo = UserRepositoryImpl(remoteDataSource: dataSource);

      final user = await repo.getUserProfile();
      expect(user.username, 'learner_1');
      expect(user.fullName, 'Test Learner');
      expect(user.englishLevel, 'Intermediate');
    });

    test('getUserProfile throws exception on non-200 status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final dataSource = UserRemoteDataSource(
        client: mockClient,
        userUrl: 'http://localhost:8000/api/v1/user',
      );
      final repo = UserRepositoryImpl(remoteDataSource: dataSource);

      expect(() => repo.getUserProfile(), throwsException);
    });
  });
}
