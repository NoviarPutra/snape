import '../../domain/models/space.dart';
import '../../domain/repositories/space_repository.dart';
import '../datasources/space_remote_data_source.dart';

class SpaceRepositoryImpl implements SpaceRepository {
  final SpaceRemoteDataSource _remoteDataSource;

  SpaceRepositoryImpl({SpaceRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? SpaceRemoteDataSource();

  @override
  Future<List<SpaceModel>> getSpaces() {
    return _remoteDataSource.getSpaces();
  }
}
