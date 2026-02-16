// 목적: MainScreen 등에서 하위 route pop 시 포커스 복귀를 감지해 권한(role) 재확인용.
// 흐름: MaterialApp navigatorObservers에 등록, MainScreen에서 RouteAware로 구독.

import 'package:flutter/material.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
