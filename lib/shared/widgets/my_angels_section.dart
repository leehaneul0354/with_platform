// 목적: 홈 화면 상단 — 내가 후원하는 천사들 섹션. donations/comments 컬렉션 기반으로 후원 중인 환자 목록 표시.
// 흐름: MainContentMobile → MyAngelsSection. 로그인한 유저의 후원 내역을 기반으로 환자 프로필 가로 리스트 표시.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/firestore_keys.dart';
import '../../../features/post/post_detail_screen.dart';

/// 내가 후원하는 천사들 섹션
class MyAngelsSection extends StatefulWidget {
  const MyAngelsSection({
    super.key,
    this.onPatientSelected,
    this.title = '내가 후원하는 천사들',
    this.showSelectionMode = false,
  });

  /// 선택 모드일 때 환자 선택 콜백 (patientId, patientName)
  final Function(String patientId, String patientName)? onPatientSelected;
  
  /// 섹션 제목
  final String title;
  
  /// 선택 모드 활성화 여부
  final bool showSelectionMode;

  @override
  State<MyAngelsSection> createState() => _MyAngelsSectionState();
}

class _MyAngelsSectionState extends State<MyAngelsSection> {
  Stream<QuerySnapshot>? _donationsStream;
  Stream<QuerySnapshot>? _commentsStream;
  String? _userId;
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      return;
    }

    _userId = user.id;
    
    // 스트림을 한 번만 생성하여 재사용
    _donationsStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.donations)
        .where(DonationKeys.userId, isEqualTo: user.id)
        .snapshots();
    
    _commentsStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.comments)
        .where(CommentKeys.userId, isEqualTo: user.id)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    
    // 비로그인 시 섹션 숨김
    if (user == null || _donationsStream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _donationsStream,
      builder: (context, donationsSnapshot) {
        // 에러 처리
        if (donationsSnapshot.hasError) {
          return _buildEmptyState();
        }
        
        // 로딩 중
        if (donationsSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 145,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        // 데이터 없음
        if (!donationsSnapshot.hasData) {
          return _buildEmptyState();
        }

        final donations = donationsSnapshot.data?.docs ?? [];
        
        if (donations.isEmpty) {
          return _buildEmptyState();
        }

        // postId 리스트 추출
        final postIds = donations
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?[DonationKeys.postId] as String?;
            })
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .toList();
        
        if (postIds.isEmpty) {
          return _buildEmptyState();
        }

        // comments에서도 후원한 환자 찾기
        return StreamBuilder<QuerySnapshot>(
          stream: _commentsStream,
          builder: (context, commentsSnapshot) {
            // comments 에러가 있어도 donations만으로 진행
            final comments = commentsSnapshot.data?.docs ?? [];
            final commentPostIds = comments
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  return data?[CommentKeys.postId] as String?;
                })
                .where((id) => id != null && id.isNotEmpty)
                .toSet()
                .toList();

            final allPostIds = {...postIds, ...commentPostIds}.toList();

            if (allPostIds.isEmpty) {
              return _buildEmptyState();
            }

            // posts에서 patientId 추출
            if (allPostIds.isEmpty) {
              return _buildEmptyState();
            }
            
            // Firestore whereIn은 최대 10개까지만 지원
            final queryPostIds = allPostIds.length > 10 
                ? allPostIds.take(10).toList() 
                : allPostIds;
            
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.posts)
                  .where(FieldPath.documentId, whereIn: queryPostIds)
                  .snapshots(),
              builder: (context, postsSnapshot) {
                // 에러 처리
                if (postsSnapshot.hasError) {
                  return _buildEmptyState();
                }
                
                // 로딩 중
                if (postsSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 145, child: Center(child: CircularProgressIndicator()));
                }
                
                if (!postsSnapshot.hasData) {
                  return _buildEmptyState();
                }

                final posts = postsSnapshot.data?.docs ?? [];
                final patientIds = <String>{};
                
                for (final postDoc in posts) {
                  final postData = postDoc.data() as Map<String, dynamic>?;
                  final patientId = postData?[FirestorePostKeys.patientId] as String?;
                  if (patientId != null && patientId.isNotEmpty) {
                    patientIds.add(patientId);
                  }
                }
                
                if (patientIds.isEmpty) {
                  return _buildEmptyState();
                }

                // 환자 정보 가져오기
                final patientIdsList = patientIds.toList();
                // Firestore whereIn은 최대 10개까지만 지원
                final queryPatientIds = patientIdsList.length > 10 
                    ? patientIdsList.take(10).toList() 
                    : patientIdsList;
                
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestoreCollections.users)
                      .where(FieldPath.documentId, whereIn: queryPatientIds)
                      .snapshots(),
                  builder: (context, usersSnapshot) {
                    // 에러 처리
                    if (usersSnapshot.hasError) {
                      return _buildEmptyState();
                    }
                    
                    // 로딩 중
                    if (usersSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(height: 145, child: Center(child: CircularProgressIndicator()));
                    }
                    
                    if (!usersSnapshot.hasData) {
                      return _buildEmptyState();
                    }

                    final users = usersSnapshot.data?.docs ?? [];
                    
                    if (users.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildAngelsList(context, users);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 145,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.inactiveBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            WithMascots.withMascot,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => Icon(
              Icons.favorite_border,
              size: 32,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '아직 후원 중인 천사가 없습니다',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.showSelectionMode 
                ? '추천 사연을 확인해보세요'
                : '당신의 후원을 기다리고 있는 사람을 찾아보세요',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToPatientPost(BuildContext context, String patientId) {
    FirebaseFirestore.instance
        .collection(FirestoreCollections.posts)
        .where(FirestorePostKeys.patientId, isEqualTo: patientId)
        .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.approved)
        .orderBy(FirestorePostKeys.createdAt, descending: true)
        .limit(1)
        .get()
        .then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              postId: doc.id,
              data: data,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('아직 승인된 게시물이 없습니다.')),
        );
      }
    }).catchError((error) {
      debugPrint('Error fetching patient post: $error');
    });
  }

  Widget _buildAngelsList(BuildContext context, List<QueryDocumentSnapshot> users) {
    return Container(
      height: 145,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userDoc = users[index];
                final userData = userDoc.data() as Map<String, dynamic>?;
                final nickname = userData?[FirestoreUserKeys.nickname] as String? ?? '이름없음';
                final userId = userDoc.id;
                final isSelected = _selectedPatientId == userId;

                return Padding(
                  padding: EdgeInsets.only(right: index == users.length - 1 ? 0 : 12),
                  child: _AngelProfileCard(
                    nickname: nickname,
                    userId: userId,
                    isSelected: widget.showSelectionMode ? isSelected : false,
                    onTap: () {
                      if (widget.showSelectionMode) {
                        // 선택 모드: 환자 선택
                        setState(() {
                          _selectedPatientId = userId;
                        });
                        if (widget.onPatientSelected != null) {
                          widget.onPatientSelected!(userId, nickname);
                        }
                      } else {
                        // 일반 모드: 환자 기록 목록으로 이동
                        if (widget.onPatientSelected != null) {
                          widget.onPatientSelected!(userId, nickname);
                        } else {
                          // 콜백이 없으면 기본 동작: 환자의 첫 번째 게시물 찾기
                          _navigateToPatientPost(context, userId);
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AngelProfileCard extends StatelessWidget {
  const _AngelProfileCard({
    required this.nickname,
    required this.userId,
    required this.onTap,
    this.isSelected = false,
  });

  final String nickname;
  final String userId;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.coral 
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.coral.withValues(alpha: 0.2),
              child: Text(
                nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.coral,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                nickname,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
