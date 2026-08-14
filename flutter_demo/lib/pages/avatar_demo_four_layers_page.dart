import 'package:flutter/material.dart';

import '../avatar_demo/application/get_user_profile_use_case.dart';
import '../avatar_demo/domain/entities/user_profile.dart';
import '../avatar_demo/infrastructure/datasources/mock_user_profile_remote_data_source.dart';
import '../avatar_demo/infrastructure/repositories/user_profile_repository_impl.dart';

class AvatarDemoFourLayersPage extends StatefulWidget {
  static const String routeName = '/avatar-demo-four-layers';

  const AvatarDemoFourLayersPage({super.key});

  @override
  State<AvatarDemoFourLayersPage> createState() =>
      _AvatarDemoFourLayersPageState();
}

class _AvatarDemoFourLayersPageState extends State<AvatarDemoFourLayersPage> {
  late final GetUserProfileUseCase _getUserProfileUseCase;

  UserProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('[展示层] initState -> 开始组装四层依赖');

    _getUserProfileUseCase = GetUserProfileUseCase(
      repository: const UserProfileRepositoryImpl(
        remoteDataSource: MockUserProfileRemoteDataSource(),
      ),
    );

    debugPrint('[展示层] initState -> 准备发起获取用户头像');
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    debugPrint('[展示层] _loadUserProfile -> 触发应用层 UseCase');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _getUserProfileUseCase();
      debugPrint('[展示层] _loadUserProfile -> 收到结果 name=${profile.name}, id=${profile.id}');

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint('[展示层] _loadUserProfile -> 加载失败 error=$error');
      setState(() {
        _errorMessage = '加载失败：$error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('四层架构：获取用户头像'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '调用链：\n'
                  '展示层 Page -> 应用层 UseCase -> 领域层 Repository 抽象 -> 基建层 Repository 实现 / DTO / DataSource',
                  style: textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildContent(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadUserProfile,
              child: const Text('重新获取头像'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('暂无数据'),
        ),
      );
    }

    return Column(
      children: [
        ClipOval(
          child: Image.network(
            profile.avatarUrl,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                width: 96,
                height: 96,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.person, size: 40),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('用户 ID: ${profile.id}'),
        const SizedBox(height: 8),
        Text(
          '这里 UI 只负责展示，不直接碰 DTO，也不直接调 DataSource。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}