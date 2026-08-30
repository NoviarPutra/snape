import '../../domain/models/memory_item.dart';
import '../../domain/repositories/memory_repository.dart';
import '../datasources/memory_remote_data_source.dart';

class MemoryRepositoryImpl implements MemoryRepository {
  final MemoryRemoteDataSource _remoteDataSource;

  MemoryRepositoryImpl({MemoryRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? MemoryRemoteDataSource();

  @override
  Future<List<MemoryItem>> getMemories({
    int limit = 50,
    int offset = 0,
    String? category,
  }) {
    return _remoteDataSource.getMemories(
      limit: limit,
      offset: offset,
      category: category,
    );
  }

  @override
  Future<void> deleteMemory(String memoryId) {
    return _remoteDataSource.deleteMemory(memoryId);
  }
}
