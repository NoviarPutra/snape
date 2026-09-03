import '../models/space.dart';

abstract class SpaceRepository {
  Future<List<SpaceModel>> getSpaces();
}
