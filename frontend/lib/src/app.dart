import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'design/app_theme.dart';

class KtmsApp extends StatelessWidget {
  const KtmsApp({required this.authService, super.key});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KTMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: LoginPage(authService: authService),
    );
  }
}
