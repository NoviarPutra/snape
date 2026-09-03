import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/material_item.dart';
import '../../domain/repositories/material_repository.dart';
import 'material_state.dart';

class MaterialNotifier extends StateNotifier<MaterialState> {
  final MaterialRepository _repository;

  MaterialNotifier(this._repository) : super(const MaterialState());

  Future<void> selectCategory(
    String spaceSlug,
    MaterialCategory category,
  ) async {
    if (state.currentSpaceSlug != spaceSlug) {
      state = MaterialState(
        currentSpaceSlug: spaceSlug,
        selectedCategory: category,
      );
      await loadMaterial(spaceSlug, category);
      return;
    }

    if (state.selectedCategory != category) {
      state = state.copyWith(
        selectedCategory: category,
        clearError: true,
      );
    }

    if (!state.loadedCategories.contains(category) ||
        state.errorMessage != null) {
      await loadMaterial(spaceSlug, category);
    }
  }

  Future<void> loadMaterial(
    String spaceSlug,
    MaterialCategory category,
  ) async {
    state = state.copyWith(
      currentSpaceSlug: spaceSlug,
      selectedCategory: category,
      isLoading: true,
      clearError: true,
    );

    try {
      final content = await _repository.getMaterial(spaceSlug, category.slug);
      final updatedContents =
          Map<MaterialCategory, String?>.from(state.categoryContents);
      updatedContents[category] = content;

      final updatedLoaded =
          Set<MaterialCategory>.from(state.loadedCategories)..add(category);

      state = state.copyWith(
        categoryContents: updatedContents,
        loadedCategories: updatedLoaded,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> retry(String spaceSlug) async {
    await loadMaterial(spaceSlug, state.selectedCategory);
  }

  void invalidate({String? newSpaceSlug}) {
    state = MaterialState(currentSpaceSlug: newSpaceSlug);
  }
}
