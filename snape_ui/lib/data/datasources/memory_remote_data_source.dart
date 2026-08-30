import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/models/memory_item.dart';

class MemoryRemoteDataSource {
  final http.Client _client;
  final String _baseHttpUrl;

  MemoryRemoteDataSource({
    http.Client? client,
    String? baseHttpUrl,
  })  : _client = client ?? http.Client(),
        _baseHttpUrl = baseHttpUrl ?? ApiConstants.baseHttpUrl;

  Future<List<MemoryItem>> getMemories({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }

    final uri = Uri.parse('$_baseHttpUrl/memories').replace(queryParameters: queryParams);
    final response = await _client.get(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> list = json.decode(response.body) as List<dynamic>;
      return list
          .map((item) => MemoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load memories: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteMemory(String memoryId) async {
    final uri = Uri.parse('$_baseHttpUrl/memories/$memoryId');
    final response = await _client.delete(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete memory: ${response.statusCode}');
    }
  }
}
