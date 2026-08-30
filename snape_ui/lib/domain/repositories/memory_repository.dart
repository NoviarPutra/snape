import '../models/memory_item.dart';

abstract class MemoryRepository {
  Future<List<MemoryItem>> getMemories({int limit = 50, int offset = 0, String? category});
  Future<void> deleteMemory(String memoryId);
}
