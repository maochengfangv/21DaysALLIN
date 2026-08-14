import 'package:flutter/foundation.dart';

import '../../domain/entities/user_profile.dart';

class UserProfileDto {
  final int? userId;
  final String? nickName;
  final String? avatarUrl;

  const UserProfileDto({
    this.userId,
    this.nickName,
    this.avatarUrl,
  });

  UserProfile toEntity() {
    debugPrint('[基建层] UserProfileDto.toEntity -> 开始 DTO 转 Entity');
    final normalizedName =
        (nickName == null || nickName!.trim().isEmpty) ? '未命名用户' : nickName!.trim();

    final entity = UserProfile(
      id: '${userId ?? 0}',
      name: normalizedName,
      avatarUrl: avatarUrl ?? 'https://i.pravatar.cc/150?img=12',
    );
    debugPrint('[基建层] UserProfileDto.toEntity -> 转换完成 id=${entity.id}, name=${entity.name}');
    return entity;
  }
}