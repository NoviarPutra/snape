import 'package:flutter/foundation.dart';
import '../../domain/models/material_item.dart';

@immutable
class MaterialState {
  final String? currentSpaceSlug;
  final MaterialCategory selectedCategory;
  final Map<MaterialCategory, String?> categoryContents;
  final Set<MaterialCategory> loadedCategories;
  final bool isLoading;
  final String? errorMessage;

  const MaterialState({
    this.currentSpaceSlug,
    this.selectedCategory = MaterialCategory.cheatsheet,
    this.categoryContents = const {},
    this.loadedCategories = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  String? get currentContent => categoryContents[selectedCategory];

  bool get isCurrentCategoryLoaded => loadedCategories.contains(selectedCategory);

  bool get isCurrentCategoryEmpty =>
      isCurrentCategoryLoaded && currentContent == null;

  MaterialState copyWith({
    String? currentSpaceSlug,
    MaterialCategory? selectedCategory,
    Map<MaterialCategory, String?>? categoryContents,
    Set<MaterialCategory>? loadedCategories,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MaterialState(
      currentSpaceSlug: currentSpaceSlug ?? this.currentSpaceSlug,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      categoryContents: categoryContents ?? this.categoryContents,
      loadedCategories: loadedCategories ?? this.loadedCategories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialState &&
          runtimeType == other.runtimeType &&
          currentSpaceSlug == other.currentSpaceSlug &&
          selectedCategory == other.selectedCategory &&
          mapEquals(categoryContents, other.categoryContents) &&
          setEquals(loadedCategories, other.loadedCategories) &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      currentSpaceSlug.hashCode ^
      selectedCategory.hashCode ^
      categoryContents.hashCode ^
      loadedCategories.hashCode ^
      isLoading.hashCode ^
      errorMessage.hashCode;
}
