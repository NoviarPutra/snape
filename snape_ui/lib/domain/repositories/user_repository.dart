import '../models/user.dart';

abstract class UserRepository {
  Future<UserModel> getUserProfile();
}
