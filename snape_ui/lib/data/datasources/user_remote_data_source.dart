import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/models/user.dart';

class UserRemoteDataSource {
  final http.Client _client;
  final String _userUrl;

  UserRemoteDataSource({
    http.Client? client,
    String? userUrl,
  })  : _client = client ?? http.Client(),
        _userUrl = userUrl ?? ApiConstants.userUrl;

  Future<UserModel> getUserProfile() async {
    final uri = Uri.parse(_userUrl);
    final response = await _client.get(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } else {
      throw Exception(
          'Failed to load user profile: ${response.statusCode} ${response.body}');
    }
  }
}
