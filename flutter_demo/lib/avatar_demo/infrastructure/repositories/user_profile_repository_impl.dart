import 'package:flutter/foundation.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/mock_user_profile_remote_data_source.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final MockUserProfileRemoteDataSource remoteDataSource;

  const UserProfileRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<UserProfile> fetchUserProfile() async {
    debugPrint('[基建层] RepositoryImpl.fetchUserProfile -> 调用 RemoteDataSource');
    final dto = await remoteDataSource.fetchUserProfile();
    debugPrint('[基建层] RepositoryImpl.fetchUserProfile -> 拿到 DTO userId=${dto.userId}, nickName=${dto.nickName}');
    final entity = dto.toEntity();
    debugPrint('[基建层] RepositoryImpl.fetchUserProfile -> DTO 转 Entity 完成');
    return entity;
  }
}