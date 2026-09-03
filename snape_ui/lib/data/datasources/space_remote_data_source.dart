import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/models/space.dart';

class SpaceRemoteDataSource {
  final http.Client _client;
  final String _baseHttpUrl;

  SpaceRemoteDataSource({
    http.Client? client,
    String? baseHttpUrl,
  })  : _client = client ?? http.Client(),
        _baseHttpUrl = baseHttpUrl ?? ApiConstants.baseHttpUrl;

  Future<List<SpaceModel>> getSpaces() async {
    final uri = Uri.parse('$_baseHttpUrl/spaces');
    final response = await _client.get(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> list = json.decode(response.body) as List<dynamic>;
      return list
          .map((item) => SpaceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load spaces: ${response.statusCode} ${response.body}');
    }
  }
}
