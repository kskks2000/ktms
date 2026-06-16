import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../carrier/carrier_home_page.dart';
import '../driver/driver_home_page.dart';
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
    final displayName = user.displayName ?? user.email ?? 'KTMS User';
    final email = user.email ?? 'authenticated@ktms.local';
    if (_isDriverAccount(displayName, email)) {
      return DriverHomePage(
        displayName: displayName,
        email: email,
        onSignOut: () => authService.signOut(),
      );
    }

    if (_isCarrierAccount(displayName, email)) {
      return CarrierHomePage(
        displayName: displayName,
        email: email,
        carrierName: _carrierName(displayName, email),
        onSignOut: () => authService.signOut(),
      );
    }

    return TmsHomePage(
      displayName: displayName,
      email: email,
      onSignOut: () => authService.signOut(),
    );
  }

  bool _isDriverAccount(String displayName, String email) {
    final normalizedName = displayName.toLowerCase();
    final normalizedEmail = email.toLowerCase();
    return normalizedEmail.contains('driver') ||
        normalizedEmail.contains('drv') ||
        normalizedName.contains('기사');
  }

  bool _isCarrierAccount(String displayName, String email) {
    final normalizedName = displayName.toLowerCase();
    final normalizedEmail = email.toLowerCase();
    return normalizedEmail.contains('carrier') ||
        normalizedEmail.contains('logistics') ||
        normalizedEmail.contains('cj') ||
        normalizedName.contains('운송사') ||
        normalizedName.contains('배차');
  }

  String _carrierName(String displayName, String email) {
    final normalized = '$displayName $email'.toLowerCase();
    if (normalized.contains('hanjin') || normalized.contains('한진')) {
      return '한진';
    }
    if (normalized.contains('oo운송')) {
      return 'OO운송';
    }
    return 'CJ대한통운';
  }
}
