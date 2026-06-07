import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../tms/tms_home_page.dart';

class SignedInPage extends StatelessWidget {
  const SignedInPage({
    required this.user,
    required this.authService,
    super.key,
  });

  final User user;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return TmsHomePage(
      displayName: user.displayName ?? user.email ?? 'KTMS User',
      email: user.email ?? 'authenticated@ktms.local',
      onSignOut: () => authService.signOut(),
    );
  }
}
