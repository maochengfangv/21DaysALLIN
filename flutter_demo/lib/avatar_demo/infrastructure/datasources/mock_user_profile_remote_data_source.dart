import 'package:flutter/foundation.dart';

import '../dto/user_profile_dto.dart';

class MockUserProfileRemoteDataSource {
  const MockUserProfileRemoteDataSource();

  Future<UserProfileDto> fetchUserProfile() async {
    debugPrint('[基建层] RemoteDataSource.fetchUserProfile -> 模拟远端请求开始');
    await Future.delayed(const Duration(milliseconds: 600));

    const dto = UserProfileDto(
      userId: 1001,
      nickName: 'Flutter 架构示例用户',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
    );
    debugPrint('[基建层] RemoteDataSource.fetchUserProfile -> 返回 DTO');
    return dto;
  }
}