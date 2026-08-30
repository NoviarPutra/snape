import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/session.dart';
import '../../domain/repositories/chat_repository.dart';
import 'providers.dart';
import 'session_state.dart';

class SessionNotifier extends StateNotifier<SessionState> {
  final ChatRepository _repository;

  SessionNotifier(this._repository) : super(const SessionState());

  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sessions = await _repository.getSessions();
      SessionModel? current = state.currentSession;
      if (current == null && sessions.isNotEmpty) {
        current = sessions.first;
      } else if (current != null && !sessions.any((s) => s.id == current!.id)) {
        current = sessions.isNotEmpty ? sessions.first : null;
      }
      state = state.copyWith(
        sessions: sessions,
        currentSession: current,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load sessions: $e',
      );
    }
  }

  void selectSession(SessionModel session) {
    if (state.currentSession?.id == session.id) return;
    state = state.copyWith(currentSession: session, clearError: true);
  }

  Future<SessionModel?> createSession({String title = 'Casual English Chat'}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newSession = await _repository.createSession(title: title);
      final updatedList = [newSession, ...state.sessions];
      state = state.copyWith(
        sessions: updatedList,
        currentSession: newSession,
        isLoading: false,
      );
      return newSession;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create new session: $e',
      );
      return null;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _repository.deleteSession(sessionId);
      final updatedList = state.sessions.where((s) => s.id != sessionId).toList();
      final isCurrent = state.currentSession?.id == sessionId;
      state = state.copyWith(
        sessions: updatedList,
        currentSession: isCurrent ? (updatedList.isNotEmpty ? updatedList.first : null) : state.currentSession,
        clearCurrentSession: isCurrent && updatedList.isEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to delete session: $e',
      );
    }
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return SessionNotifier(repository);
});
