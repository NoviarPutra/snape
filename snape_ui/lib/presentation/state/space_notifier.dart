import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/space.dart';
import '../../domain/repositories/space_repository.dart';
import 'space_state.dart';

class SpaceNotifier extends StateNotifier<SpaceState> {
  final SpaceRepository _repository;

  SpaceNotifier(this._repository) : super(const SpaceState());

  Future<void> loadSpaces() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final spaces = await _repository.getSpaces();
      state = state.copyWith(
        spaces: spaces,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load spaces: $e',
      );
    }
  }

  void selectSpace(SpaceModel space) {
    if (state.activeSpace?.slug == space.slug) return;
    state = state.copyWith(activeSpace: space, clearError: true);
  }
}
