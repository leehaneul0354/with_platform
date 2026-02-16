// 목적: userId를 기반으로 Firestore에서 사용자 정보를 가져와 프로필 아바타 표시.
// 흐름: userId → Firestore users 컬렉션 조회 → profileImage 필드 사용 → ProfileAvatar 표시.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/firestore_keys.dart';
import 'profile_avatar.dart';

/// userId를 기반으로 프로필 아바타를 표시하는 위젯
class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({
    super.key,
    required this.userId,
    this.radius = 20,
    this.backgroundColor,
  });

  final String userId;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return ProfileAvatar(
        profileImage: null,
        radius: radius,
        backgroundColor: backgroundColor,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ProfileAvatar(
            profileImage: null,
            radius: radius,
            backgroundColor: backgroundColor,
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final profileImage = userData?[FirestoreUserKeys.profileImage]?.toString();

        return ProfileAvatar(
          profileImage: profileImage,
          radius: radius,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}
