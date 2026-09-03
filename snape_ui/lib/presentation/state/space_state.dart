import 'package:flutter/foundation.dart';
import '../../domain/models/space.dart';

@immutable
class SpaceState {
  final List<SpaceModel> spaces;
  final SpaceModel? activeSpace;
  final bool isLoading;
  final String? errorMessage;

  const SpaceState({
    this.spaces = const [],
    this.activeSpace,
    this.isLoading = false,
    this.errorMessage,
  });

  SpaceState copyWith({
    List<SpaceModel>? spaces,
    SpaceModel? activeSpace,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearActiveSpace = false,
  }) {
    return SpaceState(
      spaces: spaces ?? this.spaces,
      activeSpace: clearActiveSpace ? null : (activeSpace ?? this.activeSpace),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpaceState &&
          runtimeType == other.runtimeType &&
          listEquals(spaces, other.spaces) &&
          activeSpace == other.activeSpace &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      spaces.hashCode ^
      activeSpace.hashCode ^
      isLoading.hashCode ^
      errorMessage.hashCode;
}
