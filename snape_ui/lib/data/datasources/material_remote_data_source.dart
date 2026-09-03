import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';

class MaterialRemoteDataSource {
  final http.Client _client;
  final String _baseHttpUrl;

  MaterialRemoteDataSource({
    http.Client? client,
    String? baseHttpUrl,
  })  : _client = client ?? http.Client(),
        _baseHttpUrl = baseHttpUrl ?? ApiConstants.baseHttpUrl;

  Future<String?> getMaterial(String spaceSlug, String category) async {
    final uri = Uri.parse('$_baseHttpUrl/materials/$spaceSlug/$category');
    final response = await _client.get(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return (data['content'] as String?) ?? '';
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception(
        'Failed to load material: ${response.statusCode} ${response.body}',
      );
    }
  }
}
