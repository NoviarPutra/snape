import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/domain/models/space.dart';
import 'package:snape_ui/domain/repositories/space_repository.dart';
import 'package:snape_ui/presentation/state/space_notifier.dart';

class MockSpaceRepository implements SpaceRepository {
  List<SpaceModel> spaces = [];
  bool shouldThrow = false;

  @override
  Future<List<SpaceModel>> getSpaces() async {
    if (shouldThrow) {
      throw Exception('Network error fetching spaces');
    }
    return spaces;
  }
}

void main() {
  group('SpaceNotifier', () {
    late MockSpaceRepository repository;
    late SpaceNotifier notifier;

    final testSpaces = [
      const SpaceModel(
        slug: 'english_b2',
        displayName: 'English Chat (B2)',
        cefrLevel: 'B2',
        voiceCallEnabled: true,
        ttsEnabled: true,
      ),
      const SpaceModel(
        slug: 'tech',
        displayName: 'Technology & Architecture',
        cefrLevel: null,
        voiceCallEnabled: false,
        ttsEnabled: false,
      ),
      const SpaceModel(
        slug: 'psychology',
        displayName: 'Psychology & Mental Models',
        cefrLevel: null,
        voiceCallEnabled: false,
        ttsEnabled: false,
      ),
    ];

    setUp(() {
      repository = MockSpaceRepository();
      repository.spaces = List.from(testSpaces);
      notifier = SpaceNotifier(repository);
    });

    test('initial state has empty spaces and no active space', () {
      expect(notifier.state.spaces, isEmpty);
      expect(notifier.state.activeSpace, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
    });

    test('loadSpaces() fills state with list of spaces', () async {
      await notifier.loadSpaces();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.spaces.length, 3);
      expect(notifier.state.spaces.first.slug, 'english_b2');
      expect(notifier.state.errorMessage, isNull);
    });

    test('selectSpace() updates activeSpace', () async {
      await notifier.loadSpaces();
      final techSpace = notifier.state.spaces[1];

      notifier.selectSpace(techSpace);

      expect(notifier.state.activeSpace, equals(techSpace));
      expect(notifier.state.activeSpace?.slug, 'tech');
    });

    test('loadSpaces() sets errorMessage when fetch fails', () async {
      repository.shouldThrow = true;

      await notifier.loadSpaces();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.spaces, isEmpty);
      expect(notifier.state.errorMessage, contains('Network error fetching spaces'));
    });
  });
}
