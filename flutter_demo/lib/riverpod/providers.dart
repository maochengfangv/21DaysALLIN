import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar_demo/application/get_user_profile_use_case.dart';
import '../avatar_demo/domain/entities/user_profile.dart';
import '../avatar_demo/domain/repositories/user_profile_repository.dart';
import '../avatar_demo/infrastructure/datasources/mock_user_profile_remote_data_source.dart';
import '../avatar_demo/infrastructure/repositories/user_profile_repository_impl.dart';

/// 依赖注入：Repository 实现（可在测试 / 多环境下通过 override 替换）
final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>((Ref ref) {
  return const UserProfileRepositoryImpl(
    remoteDataSource: MockUserProfileRemoteDataSource(),
  );
});

/// 依赖注入：UseCase，依赖上面的 Repository Provider
final Provider<GetUserProfileUseCase> getUserProfileUseCaseProvider =
    Provider<GetUserProfileUseCase>((Ref ref) {
  final UserProfileRepository repository =
      ref.watch(userProfileRepositoryProvider);
  return GetUserProfileUseCase(repository: repository);
});

/// 简单可变状态：计数器
final StateProvider<int> counterProvider = StateProvider<int>((Ref ref) => 0);

/// 异步状态：获取用户头像，自动处理 loading / error / data
final FutureProvider<UserProfile> userProfileFutureProvider =
    FutureProvider<UserProfile>((Ref ref) async {
  final GetUserProfileUseCase useCase =
      ref.watch(getUserProfileUseCaseProvider);
  return useCase();
});
