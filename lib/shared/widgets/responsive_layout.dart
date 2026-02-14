// 목적: 모바일/웹에 따라 다른 자식 위젯을 보여주는 반응형 래퍼.
// 흐름: 메인 스캐폴드 body에서 감싸기 → 모바일/데스크톱 자식 분기.

import 'package:flutter/material.dart';
import '../../core/util/responsive_util.dart';

/// 화면 너비에 따라 [mobileChild] 또는 [desktopChild]를 표시하는 레이아웃.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobileChild,
    required this.desktopChild,
  });

  /// 모바일(좁은 화면)에서 표시할 위젯
  final Widget mobileChild;

  /// 웹/데스크톱(넓은 화면)에서 표시할 위젯
  final Widget desktopChild;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveHelper.isMobile(context)) {
          return mobileChild;
        }
        return desktopChild;
      },
    );
  }
}
