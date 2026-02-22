// 목적: 어드민 게시물 상세 — imageUrl, title, content, badgeText 표시. 하단 [관련 페이지로 이동하기]로 linkUrl 열기.
// 흐름: 탐색 탭 어드민 카드 클릭 → 본 화면 → 버튼 클릭 시 url_launcher로 외부 링크.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../shared/widgets/brand_placeholder.dart';

/// 어드민 게시물 상세 — 일반 후원 게시물 상세와 톤·매너 통일. 하단만 '관련 페이지로 이동하기' 버튼.
class AdminPostDetailScreen extends StatelessWidget {
  const AdminPostDetailScreen({
    super.key,
    required this.data,
  });

  final Map<String, dynamic> data;

  String get _title => data[AdminPostKeys.title]?.toString() ?? '(제목 없음)';
  String get _content => data[AdminPostKeys.content]?.toString() ?? '';
  String? get _imageUrl {
    final v = data[AdminPostKeys.imageUrl]?.toString();
    return (v != null && v.isNotEmpty) ? v : null;
  }

  String? get _badgeText {
    final v = data[AdminPostKeys.badgeText]?.toString();
    return (v != null && v.isNotEmpty) ? v : null;
  }

  String? get _linkUrl {
    final v = data[AdminPostKeys.linkUrl]?.toString();
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> _onLinkTap(BuildContext context) async {
    final url = _linkUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크를 열 수 없습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = _linkUrl != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_imageUrl != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: _imageUrl!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          placeholder: (_, __) => AspectRatio(
                            aspectRatio: 16 / 9,
                            child: BrandPlaceholder.forContent(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: AppColors.inactiveBackground.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: const Center(
                                child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_badgeText != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _badgeText!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.coral,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _content,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasLink)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _onLinkTap(context),
                    icon: const Icon(Icons.open_in_new, size: 20),
                    label: const Text('관련 페이지로 이동하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
