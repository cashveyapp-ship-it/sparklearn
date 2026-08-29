import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sparklearn/router/app_router.dart';

final _testRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Material(
        child: Center(child: Text('TEST HOME')),
      ),
    ),
  ],
);

List<Override> overridesForTests() => [
  goRouterProvider.overrideWithValue(_testRouter),
];