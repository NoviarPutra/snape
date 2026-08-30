import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repository = ChatRepositoryImpl();
  ref.onDispose(() => repository.dispose());
  return repository;
});
