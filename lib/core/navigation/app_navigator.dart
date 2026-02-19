// 목적: 전역 Navigator Key 관리 - 화면 context와 상관없이 어디서든 네비게이션 가능
// 흐름: 회원 탈퇴 등 context가 유효하지 않을 때도 안전하게 화면 전환 가능

import 'package:flutter/material.dart';

/// 전역 Navigator Key (화면 context와 상관없이 어디서든 네비게이션 가능)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
