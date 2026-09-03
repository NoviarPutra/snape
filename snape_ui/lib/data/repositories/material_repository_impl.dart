import '../../domain/repositories/material_repository.dart';
import '../datasources/material_remote_data_source.dart';

class MaterialRepositoryImpl implements MaterialRepository {
  final MaterialRemoteDataSource _remoteDataSource;

  MaterialRepositoryImpl({MaterialRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? MaterialRemoteDataSource();

  @override
  Future<String?> getMaterial(String spaceSlug, String category) {
    return _remoteDataSource.getMaterial(spaceSlug, category);
  }
}
