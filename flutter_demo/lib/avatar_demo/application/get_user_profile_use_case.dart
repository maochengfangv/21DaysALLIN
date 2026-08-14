import 'package:flutter/foundation.dart';

import '../domain/entities/user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';

class GetUserProfileUseCase {
  final UserProfileRepository repository;

  const GetUserProfileUseCase({
    required this.repository,
  });

  Future<UserProfile> call() async {
    debugPrint('[应用层] GetUserProfileUseCase.call -> 开始调用 Repository');
    final profile = await repository.fetchUserProfile();
    debugPrint('[应用层] GetUserProfileUseCase.call -> 返回 Entity id=${profile.id}, name=${profile.name}');
    return profile;
  }
}