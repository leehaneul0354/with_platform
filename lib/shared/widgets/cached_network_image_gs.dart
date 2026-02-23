// 목적: imageUrls가 gs:// 또는 https일 때 통일된 이미지 렌더링. gs://는 getDownloadURL() 후 표시.
// 하이브리드: https://(imgbb 등)은 변환 없이 그대로 사용. gs://만 resolveImageUrl로 변환 후 표시.
// 웹: CORS 회피를 위해 getDownloadURL()로 얻은 URL은 Image.network(헤더 없음) 사용. 모바일: CachedNetworkImage.
// 흐름: gs_url_resolver.resolveImageUrl → 캐시/변환 URL → (웹) Image.network | (비웹) CachedNetworkImage.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/services/gs_url_resolver.dart';
import 'brand_placeholder.dart';

/// gs:// 또는 https URL을 처리하는 CachedNetworkImage 래퍼. gs://는 한 번 변환 후 메모리 캐시 사용.
class CachedNetworkImageGs extends StatelessWidget {
  const CachedNetworkImageGs({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.fadeInDuration,
  });

  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final BorderRadius? borderRadius;
  /// 로딩 완료 후 이미지 페이드인 시간. null이면 애니메이션 없음.
  final Duration? fadeInDuration;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildPlaceholder(context);
    }

    final url = imageUrl!.trim();
    // 웹/비웹을 최상단에서 분기 처리
    if (kIsWeb) {
      return _buildWebImage(context, url);
    }
    return _buildNonWebImage(context, url);
  }

  /// 비웹(모바일/데스크톱): resolve() 완료 후 CachedNetworkImage로 렌더링
  Widget _buildNonWebImage(BuildContext context, String url) {
    // 모든 URL을 resolve()로 통일: gs:// → getDownloadURL 결과, https:// → 그대로 반환.
    return FutureBuilder<String?>(
      future: resolve(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildPlaceholder(context);
        }
        if (!snapshot.hasData) {
          return _buildError(context);
        }
        final resolved = snapshot.data!.trim();
        if (resolved.isEmpty) {
          return _buildError(context);
        }
        // resolve() 결과를 그대로 CachedNetworkImage에 전달 (웹 아님 → CORS 이슈 없음)
        return _buildCachedImage(context, resolved);
      },
    );
  }

  /// 웹: FutureBuilder + Image.network만 사용. resolve()가 https://를 돌려주기 전까지 절대 Image.network 호출 금지.
  Widget _buildWebImage(BuildContext context, String url) {
    return FutureBuilder<String?>(
      future: resolve(url),
      builder: (context, snapshot) {
        // 1) Future가 끝나기 전에는 어떤 URL도 사용하지 않고 대기 (플레이스홀더만 노출)
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildPlaceholder(context);
        }
        if (!snapshot.hasData) {
          return _buildError(context);
        }
        final resolved = snapshot.data!.trim();
        if (resolved.isEmpty) {
          return _buildError(context);
        }
        final lower = resolved.toLowerCase();
        // 2) 반드시 https:// 로 시작하는 완전한 URL만 허용
        if (!lower.startsWith('https://')) {
          return _buildPlaceholder(context);
        }
        // 이중 방어: 혹시라도 gs://가 남아있다면 즉시 중단
        if (lower.startsWith('gs://')) {
          return _buildPlaceholder(context);
        }

        Widget image = Image.network(
          resolved,
          fit: fit,
          width: width,
          height: height,
          // 로딩 중에는 스켈레톤/플레이스홀더 유지
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder != null
                ? placeholder!(context, resolved)
                : _buildPlaceholder(context);
          },
          // 에러 시 콘솔에 위젯 레벨에서 처리하여 붉은 에러 위젯이 뜨지 않도록 방어
          errorBuilder: (context, error, stackTrace) {
            return errorWidget != null
                ? errorWidget!(context, resolved, error)
                : _buildError(context);
          },
        );

        if (fadeInDuration != null) {
          image = _FadeIn(duration: fadeInDuration!, child: image);
        }
        if (borderRadius != null) {
          image = ClipRRect(
            borderRadius: borderRadius!,
            child: image,
          );
        }
        return image;
      },
    );
  }

  Widget _buildCachedImage(BuildContext context, String url) {
    final child = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder != null
          ? (_, __) => placeholder!(context, url)
          : (_, __) => _buildPlaceholder(context),
      errorWidget: errorWidget != null
          ? (_, __, e) => errorWidget!(context, url, e)
          : (_, __, ___) => _buildError(context),
      imageBuilder: fadeInDuration != null
          ? (_, imageProvider) => _FadeIn(
                duration: fadeInDuration!,
                child: Image(
                  image: imageProvider,
                  fit: fit,
                  width: width,
                  height: height,
                ),
              )
          : null,
    );
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: width != null && height != null
            ? BrandPlaceholder.forContent(width: width, height: height, borderRadius: borderRadius)
            : const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: BrandPlaceholder(emoji: '🖼', borderRadius: borderRadius),
    );
  }
}

/// 로딩 완료 후 opacity 0 → 1 페이드인.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}
