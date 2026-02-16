// 목적: 사용자 프로필 아바타 위젯. Firestore의 profileImage 필드를 참조하여 마스코트 표시.
// 흐름: 모든 화면에서 프로필 이미지 표시 시 사용. profileImage가 없으면 기본값 사용.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../shared/widgets/safe_image_asset.dart';

/// 사용자 프로필 아바타 위젯
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profileImage,
    this.radius = 20,
    this.backgroundColor,
  });

  /// 프로필 이미지 파일명 (예: 'profile_yellow.png' 또는 null)
  final String? profileImage;
  
  /// 아바타 반지름
  final double radius;
  
  /// 배경색 (기본값: 회색)
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // profileImage가 없거나 비어있으면 기본값 사용
    String imagePath;
    if (profileImage == null || profileImage!.isEmpty) {
      imagePath = AppAssets.defaultProfile;
    } else {
      // 중복 경로 방지를 위해 정규화
      String normalized = profileImage!.trim();
      
      // with_mascot.png 같은 존재하지 않는 파일명을 기본값으로 교체
      if (normalized.contains('with_mascot.png')) {
        normalized = AppAssets.getFileName(AppAssets.defaultProfile);
      }
      
      // 중복 경로 제거 (assets/assets/ → assets/)
      while (normalized.contains('assets/assets/')) {
        normalized = normalized.replaceFirst('assets/assets/', 'assets/');
      }
      
      imagePath = AppAssets.getFullPath(normalized);
      
      // 최종 경로에서도 중복 경로 제거 (방어 코드)
      while (imagePath.contains('assets/assets/')) {
        imagePath = imagePath.replaceFirst('assets/assets/', 'assets/');
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.inactiveBackground,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: SafeImageAsset(
            assetPath: imagePath,
            fit: BoxFit.contain,
            fallback: Icon(
              Icons.person,
              size: radius,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
