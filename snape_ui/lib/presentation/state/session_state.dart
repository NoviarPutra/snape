import 'package:flutter/foundation.dart';
import '../../domain/models/session.dart';

@immutable
class SessionState {
  final List<SessionModel> sessions;
  final SessionModel? currentSession;
  final bool isLoading;
  final String? errorMessage;

  const SessionState({
    this.sessions = const [],
    this.currentSession,
    this.isLoading = false,
    this.errorMessage,
  });

  SessionState copyWith({
    List<SessionModel>? sessions,
    SessionModel? currentSession,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearCurrentSession = false,
  }) {
    return SessionState(
      sessions: sessions ?? this.sessions,
      currentSession: clearCurrentSession ? null : (currentSession ?? this.currentSession),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          listEquals(sessions, other.sessions) &&
          currentSession == other.currentSession &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      sessions.hashCode ^
      currentSession.hashCode ^
      isLoading.hashCode ^
      errorMessage.hashCode;
}
